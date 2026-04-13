#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "erreur.h"
#include "tablesymb.h"

SymbolTable* table_globale = NULL;
SymbolTable* table_courante = NULL;

static Symbol* current_function = NULL;
static Symbol* current_struct = NULL;

static int anonymous_counter = 0;

static int hash(const char* s, const int a, const int m) {
    long hash_val = 0;
    while (*s) {
        hash_val = (hash_val * a + *s) % m;
        s++;
    }
    return (int)hash_val;
}

static int get_hash(const char* s, const int num_buckets, const int attempt) {
    const int hash_a = hash(s, 151, num_buckets);
    int hash_b = hash(s, 163, num_buckets);
    if (hash_b == 0) hash_b = 1;
    return (hash_a + (attempt * hash_b)) % num_buckets;
}

Table* new_table(int size) {
    Table* ht = malloc(sizeof(Table));
    if (!ht) return NULL;
    ht->size = size;
    ht->count = 0;
    ht->items = calloc((size_t)size, sizeof(Item*));
    return ht;
}

SymbolTable* new_symbol_table(SymbolTable* parent, int niveau, int HT_SIZE) {
    SymbolTable* st = malloc(sizeof(SymbolTable));
    if (!st) return NULL;
    st->ht = new_table(HT_SIZE);
    st->parent = parent;
    st->niveau = niveau;
    return st;
}

Symbol* new_symbol_var(char* name, char* type_nom, int is_ptr, int is_ext) {
    Symbol* s = malloc(sizeof(Symbol));
    if (!s) return NULL;
    s->name = strdup(name);
    s->kind = SYMBOL_VAR;
    s->data.var = malloc(sizeof(VarInfo));
    s->data.var->type.nom_type = strdup(type_nom);
    s->data.var->type.is_pointer = is_ptr;
    s->data.var->is_extern = is_ext;
    return s;
}

Symbol* new_symbol_struct(char* name) {
    Symbol* s = malloc(sizeof(Symbol));
    if (!s) return NULL;
    s->name = strdup(name);
    s->kind = SYMBOL_STRUCT;
    s->data.str = malloc(sizeof(StructInfo));
    s->data.str->nom = strdup(name);
    s->data.str->champs = NULL;
    s->data.str->taille_totale = 0;
    return s;
}

Symbol* new_symbol_fonc(char* name, char* ret_type_nom, int ret_is_ptr, int is_ext) {
    Symbol* s = malloc(sizeof(Symbol));
    if (!s) return NULL;
    s->name = strdup(name);
    s->kind = SYMBOL_FONC;
    s->data.fonc = malloc(sizeof(FoncInfo));
    s->data.fonc->return_type.nom_type = strdup(ret_type_nom);
    s->data.fonc->return_type.is_pointer = ret_is_ptr;
    s->data.fonc->is_extern = is_ext;
    s->data.fonc->nb_params = 0;
    s->data.fonc->params = NULL;
    return s;
}

void add_field_to_struct(Symbol* struct_sym, char* field_name, char* type_nom, int is_ptr) {
    if (!struct_sym || struct_sym->kind != SYMBOL_STRUCT) return;
    
    Field* f = struct_sym->data.str->champs;
    while (f) {
        if (strcmp(f->name, field_name) == 0) {
            char msg[256];
            snprintf(msg, sizeof(msg), "Champ '%s' déjà défini dans la structure", field_name);
            erreur(SEMANTIQUE, 0, msg, field_name);
            return;
        }
        f = f->next;
    }
    
    Field* new_f = malloc(sizeof(Field));
    new_f->name = strdup(field_name);
    new_f->type.nom_type = strdup(type_nom);
    new_f->type.is_pointer = is_ptr;
    new_f->next = NULL;
    
    /* Calcul de l'offset */
    Field** curr = (Field**)&(struct_sym->data.str->champs);
    int current_offset = 0;
    while (*curr != NULL) {
        current_offset += ((*curr)->type.is_pointer) ? 8 : 4;
        curr = &((*curr)->next);
    }
    new_f->offset = current_offset;
    *curr = new_f;
    
    int size_field = (is_ptr) ? 8 : 4;
    struct_sym->data.str->taille_totale += size_field;
}

void add_param_to_function(Symbol* fonc_sym, char* type_nom, int is_ptr) {
    if (!fonc_sym || fonc_sym->kind != SYMBOL_FONC) return;
    
    Param* new_p = malloc(sizeof(Param));
    new_p->type.nom_type = strdup(type_nom);
    new_p->type.is_pointer = is_ptr;
    new_p->next = NULL;
    
    Param** curr = &(fonc_sym->data.fonc->params);
    while (*curr != NULL) {
        curr = &((*curr)->next);
    }
    *curr = new_p;
    fonc_sym->data.fonc->nb_params++;
}

static Symbol* ht_search_local(Table* ht, const char* key) {
    if (!ht) return NULL;
    int i = 0;
    int index = get_hash(key, ht->size, i);
    while (ht->items[index] != NULL) {
        if (strcmp(ht->items[index]->key, key) == 0) {
            return ht->items[index]->symbol;
        }
        index = get_hash(key, ht->size, ++i);
        if (i >= ht->size) break;
    }
    return NULL;
}

Symbol* ts_lookup(SymbolTable* st, const char* name) {
    while (st != NULL) {
        Symbol* s = ht_search_local(st->ht, name);
        if (s != NULL) return s;
        st = st->parent;
    }
    return NULL;
}

void ts_insert(SymbolTable* st, Symbol* sym, int ligne) {
    if (!st || !st->ht) return;
    
    if (st->ht->count >= st->ht->size * 0.7) {
        fprintf(stderr, "Erreur fatale : Table des symboles saturée (Niveau %d).\n", st->niveau);
        exit(1);
    }
    
    if (ht_search_local(st->ht, sym->name) != NULL) {
        char texte[256];
        snprintf(texte, sizeof(texte), 
                 "La variable '%s' a déjà été déclarée au niveau %d", 
                 sym->name, st->niveau);
        erreur(SEMANTIQUE, ligne, texte, sym->name);
        return;
    }
    
    int i = 0;
    int index = get_hash(sym->name, st->ht->size, i);
    while (st->ht->items[index] != NULL) {
        index = get_hash(sym->name, st->ht->size, ++i);
    }
    
    Item* item = malloc(sizeof(Item));
    item->key = strdup(sym->name);
    item->symbol = sym;
    st->ht->items[index] = item;
    st->ht->count++;
}

void free_symbol(Symbol* s) {
    if (!s) return;
    free(s->name);
    switch (s->kind) {
        case SYMBOL_VAR:
            free(s->data.var->type.nom_type);
            free(s->data.var);
            break;
        case SYMBOL_STRUCT:
            {
                Field* f = (Field*)s->data.str->champs;
                while (f) {
                    Field* tmp = f;
                    f = f->next;
                    free(tmp->name);
                    free(tmp->type.nom_type);
                    free(tmp);
                }
                free(s->data.str->nom);
                free(s->data.str);
            }
            break;
        case SYMBOL_FONC:
            {
                Param* p = s->data.fonc->params;
                while (p) {
                    Param* tmp = p;
                    p = p->next;
                    free(tmp->type.nom_type);
                    free(tmp);
                }
                free(s->data.fonc->return_type.nom_type);
                free(s->data.fonc);
            }
            break;
    }
    free(s);
}

void free_table(Table* ht) {
    if (!ht) return;
    for (int i = 0; i < ht->size; i++) {
        if (ht->items[i] != NULL) {
            free(ht->items[i]->key);
            free_symbol(ht->items[i]->symbol);
            free(ht->items[i]);
        }
    }
    free(ht->items);
    free(ht);
}

void del_symbol_table(SymbolTable* st) {
    if (!st) return;
    free_table(st->ht);
    free(st);
}

void enter_scope(void) {
    SymbolTable* new_scope = new_symbol_table(table_courante, 
                                               table_courante ? table_courante->niveau + 1 : 1, 
                                               100);
    if (!new_scope) {
        fprintf(stderr, "Erreur: Impossible de créer une nouvelle portée\n");
        exit(1);
    }
    table_courante = new_scope;
}

void exit_scope(void) {
    if (table_courante && table_courante->parent) {
        SymbolTable* old = table_courante;
        table_courante = table_courante->parent;
        del_symbol_table(old);
    }
}

void* create_param_list(void) {
    ParamList* list = malloc(sizeof(ParamList));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return (void*)list;
}

void add_param_to_list(void* param_list, char* type_nom, int is_pointer) {
    if (!param_list) return;
    ParamList* list = (ParamList*)param_list;
    
    Param* new_param = malloc(sizeof(Param));
    new_param->type.nom_type = strdup(type_nom);
    new_param->type.is_pointer = is_pointer;
    new_param->next = NULL;
    
    if (list->last) {
        list->last->next = new_param;
        list->last = new_param;
    } else {
        list->first = new_param;
        list->last = new_param;
    }
    list->count++;
}

void free_param_list(ParamList* list) {
    if (!list) return;
    Param* p = list->first;
    while (p) {
        Param* tmp = p;
        p = p->next;
        free(tmp->type.nom_type);
        free(tmp);
    }
    free(list);
}

Symbol* create_function_symbol(char* name, int nb_params, void* param_list) {
    Symbol* existing = ts_lookup(table_courante, name);
    if (existing && existing->kind == SYMBOL_FONC) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Fonction '%s' déjà définie", name);
        erreur(SEMANTIQUE, 0, msg, name);
        return existing;
    }
    
    Symbol* s = new_symbol_fonc(name, "int", 0, 0);
    if (!s) return NULL;
    
    if (param_list) {
        ParamList* list = (ParamList*)param_list;
        Param* p = list->first;
        while (p) {
            add_param_to_function(s, p->type.nom_type, p->type.is_pointer);
            p = p->next;
        }
        free_param_list(list);
    }
    
    if (table_courante) {
        ts_insert(table_courante, s, 0);
    }
    
    current_function = s;
    return s;
}

void end_function_definition(Symbol* func) {
    if (!func) return; 
    current_function = NULL;
}

Symbol* get_current_function(void) {
    return current_function;
}

void declare_variable(char* name, char* type_nom, int is_pointer, int is_extern) {
    if (!table_courante) return;
    
    Symbol* existing = ts_lookup(table_courante, name);
    if (existing && existing->kind == SYMBOL_VAR) {
    }
    
    Symbol* sym = new_symbol_var(name, type_nom, is_pointer, is_extern);
    if (sym) {
        ts_insert(table_courante, sym, 0);
    }
}

void check_identifier_declared(char* name) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Identifiant '%s' non déclaré", name);
        erreur(SEMANTIQUE, 0, msg, name);
    }
}

Symbol* get_identifier_symbol(char* name) {
    return ts_lookup(table_courante, name);
}

void check_function_call(char* name) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Fonction '%s' non déclarée", name);
        erreur(SEMANTIQUE, 0, msg, name);
        return;
    }
    
    if (s->kind != SYMBOL_FONC) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction", name);
        erreur(SEMANTIQUE, 0, msg, name);
    }
}

void check_function_call_with_args(char* name, int nb_params) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Fonction '%s' non déclarée", name);
        erreur(SEMANTIQUE, 0, msg, name);
        return;
    }
    
    if (s->kind != SYMBOL_FONC) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction", name);
        erreur(SEMANTIQUE, 0, msg, name);
        return;
    }
    
    if (s->data.fonc->nb_params != nb_params) {
        char msg[256];
        snprintf(msg, sizeof(msg), 
                 "Nombre de paramètres incorrect pour '%s' : attendu %d, reçu %d",
                 name, s->data.fonc->nb_params, nb_params);
        erreur(SEMANTIQUE, 0, msg, name);
    }
}

char* declare_struct(char* name) {
    Symbol* existing = ts_lookup(table_courante, name);
    if (existing && existing->kind == SYMBOL_STRUCT) {
        current_struct = existing;
        return strdup(name);
    }
    
    Symbol* s = new_symbol_struct(name);
    if (table_courante && s) {
        ts_insert(table_courante, s, 0);
    }
    current_struct = s;
    return strdup(name);
}

char* declare_anonymous_struct(void) {
    char anon_name[64];
    snprintf(anon_name, sizeof(anon_name), "__anon_%d__", anonymous_counter++);
    
    Symbol* s = new_symbol_struct(anon_name);
    if (table_courante && s) {
        ts_insert(table_courante, s, 0);
    }
    current_struct = s;
    return strdup(anon_name);
}

char* define_struct(char* name) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        s = new_symbol_struct(name);
        if (table_courante && s) {
            ts_insert(table_courante, s, 0);
        }
    } else if (s->kind != SYMBOL_STRUCT) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une structure", name);
        erreur(SEMANTIQUE, 0, msg, name);
    }
    
    current_struct = s;
    return strdup(name);
}

void add_struct_field(char* field_name, char* type_nom, int is_pointer) {
    if (!current_struct) {
        erreur(SEMANTIQUE, 0, 
               "Ajout de champ en dehors d'une définition de structure", 
               field_name);
        if (type_nom) free(type_nom);
        return;
    }
    
    add_field_to_struct(current_struct, field_name, type_nom, is_pointer);
}

void check_struct_field_access(char* struct_name, char* field_name) {
    Symbol* s = ts_lookup(table_courante, struct_name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Type de structure '%s' inconnu", struct_name);
        erreur(SEMANTIQUE, 0, msg, struct_name);
        return;
    }
    
    if (s->kind != SYMBOL_STRUCT) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une structure", struct_name);
        erreur(SEMANTIQUE, 0, msg, struct_name);
        return;
    }
    
    Field* f = s->data.str->champs;
    while (f) {
        if (strcmp(f->name, field_name) == 0) {
            return; /* Champ trouvé */
        }
        f = f->next;
    }
    
    char msg[256];
    snprintf(msg, sizeof(msg), "Champ '%s' non trouvé dans la structure '%s'", 
             field_name, struct_name);
    erreur(SEMANTIQUE, 0, msg, field_name);
}

Symbol* get_current_struct(void) {
    return current_struct;
}

void set_current_struct(Symbol* s) {
    current_struct = s;
}

void check_return_statement(void* expr_type) {
    if (!current_function) {
        erreur(SEMANTIQUE, 0, 
               "Instruction return en dehors d'une fonction", 
               "return");
        return;
    }
}

void check_return_without_value(void) {
    if (!current_function) {
        erreur(SEMANTIQUE, 0, 
               "Instruction return en dehors d'une fonction", 
               "return");
        return;
    }
    
    if (strcmp(current_function->data.fonc->return_type.nom_type, "void") != 0) {
        erreur(SEMANTIQUE, 0, 
               "return sans valeur dans une fonction qui retourne une valeur", 
               "return");
    }
}

void check_return_with_value(void) {
    if (!current_function) {
        erreur(SEMANTIQUE, 0, 
               "Instruction return en dehors d'une fonction", 
               "return");
        return;
    }
    
    if (strcmp(current_function->data.fonc->return_type.nom_type, "void") == 0) {
        erreur(SEMANTIQUE, 0, 
               "return avec valeur dans une fonction void", 
               "return");
    }
}

void error_direct_struct_access(char* field_name) {
    erreur(SEMANTIQUE, 0, 
           "Accès direct à structure non supporté, utilisez ->", 
           field_name);
}

void error_unsupported(char* feature) {
    erreur(SEMANTIQUE, 0, 
           "Instruction non supportée", 
           feature);
}

void error_redeclaration(char* name, int niveau) {
    char msg[256];
    snprintf(msg, sizeof(msg), 
             "Redéclaration de '%s' dans la même portée (niveau %d)", 
             name, niveau);
    erreur(SEMANTIQUE, 0, msg, name);
}

void free_str(char* s) {
    if (s) free(s);
}

void free_data_type(DataType* dt) {
    if (dt) {
        free(dt->nom_type);
        free(dt);
    }
}