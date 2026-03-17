#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "erreur.h"

typedef enum { SYMBOL_VAR, SYMBOL_STRUCT, SYMBOL_FONC } symbol_type;

/*Représentation d'un type (int, struct ou pointeur)*/
typedef struct {
    char* nom_type;    // "int" ou nom de la struct
    int is_pointer;    // 1 si pointeur, 0 sinon
} DataType;

/* Métadonnées spécifiques */
typedef struct {
    DataType type;
    int is_extern; 
} VarInfo;

typedef struct {
    char* nom;
    void* champs; 
    int taille_totale;
} StructInfo;
/* Structure pour représenter un champ (membre) de struct */
typedef struct Field {
    char* name;
    DataType type;
    int offset;
    struct Field* next;
} Field;

typedef struct {
    DataType return_type;
    int nb_params;
    Param** params; /*liste des paramètres (type des paramères)*/
    int is_extern;
} FoncInfo;
/* Structure pour représenter un paramètre de fonction */
typedef struct Param {
    DataType type;
    struct Param* next;
} Param;

/*entrée d'une table des symboles*/
typedef struct {
    char* name;
    symbol_type kind;
    union {         //pour réduire la taille en mémoire
        VarInfo* var;
        StructInfo* str;
        FoncInfo* fonc;
    } data;
} Symbol;

/*item de la table*/
typedef struct {
    char* key;
    Symbol* symbol;
} Item;

/*table de hachage*/
typedef struct {
    int size;
    int count;
    Item** items;
} Table;

typedef struct SymbolTable {
    Table* ht;
    int niveau;
    struct SymbolTable* parent; // Chaînage pour la remontée de portée
} SymbolTable;

/*Méthode de hashage*/
static int hash(const char* s, const int a, const int m) {
    long hash_val = 0;
    while (*s) {
        /*Formule de Horner*/
        hash_val = (hash_val * a + *s) % m;
        s++;
    }
    return (int)hash_val;
}
static int get_hash(const char* s, const int num_buckets, const int attempt) { /*gestion des collisions par adressage ouvert*/
    const int hash_a = hash(s, 151, num_buckets);
    int hash_b = hash(s, 163, num_buckets);
    if (hash_b == 0) hash_b = 1; 
    return (hash_a + (attempt * hash_b)) % num_buckets;
}

// Initialisation des Tables
Table* new_table(int size) {
    Table* ht = malloc(sizeof(Table));
    ht->size = size;
    ht->count = 0;
    ht->items = calloc((size_t)size, sizeof(Item*)); // Initialise à NULL
    return ht;
}
SymbolTable* new_symbol_table(SymbolTable* parent, int niveau,int HT_SIZE) {
    SymbolTable* st = malloc(sizeof(SymbolTable));
    st->ht = new_table(HT_SIZE);
    st->parent = parent;
    st->niveau = niveau;
    return st;
}
// Initialisation des Symboles

Symbol* new_symbol_var(char* name, char* type_nom, int is_ptr, int is_ext) {
    Symbol* s = malloc(sizeof(Symbol));
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
    s->name = strdup(name);
    s->kind = SYMBOL_STRUCT;
    s->data.str = malloc(sizeof(StructInfo));
    s->data.str->nom = strdup(name);
    s->data.str->champs = NULL; // Liste de Field*
    s->data.str->taille_totale = 0;
    return s;
}
/* Fonction pour ajouter un champ à une structure */
void add_field_to_struct(Symbol* struct_sym, char* field_name, char* type_nom, int is_ptr) {
    if (struct_sym->kind != SYMBOL_STRUCT) return;
    Field* new_f = malloc(sizeof(Field));
    new_f->name = strdup(field_name);
    new_f->type.nom_type = strdup(type_nom);
    new_f->type.is_pointer = is_ptr;
    new_f->next = NULL;
    // Calcul de l'offset (simplifié : int = 4 octets, pointeur = 8 octets)
    int size_field = (is_ptr) ? 8 : 4; 
    // Insertion en fin de liste
    Field** curr = (Field**)&(struct_sym->data.str->champs);
    int current_offset = 0;
    while (*curr != NULL) {
        current_offset += ((*curr)->type.is_pointer) ? 8 : 4;
        curr = &((*curr)->next);
    }
    new_f->offset = current_offset;
    *curr = new_f;
    struct_sym->data.str->taille_totale += size_field;
}
Symbol* new_symbol_fonc(char* name, char* ret_type_nom, int ret_is_ptr, int is_ext) {
    Symbol* s = malloc(sizeof(Symbol));
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
/*Fonction pour ajouter un param à une fonction*/
void add_param_to_function(Symbol* fonc_sym, char* type_nom, int is_ptr) {
    if (fonc_sym->kind != SYMBOL_FONC) return;
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

/*Suppression : libération de la mémoire*/
void free_symbol(Symbol* s) {
    if (!s) return;
    free(s->name);
    switch (s->kind) {
        case SYMBOL_VAR:
            free(s->data.var->type.nom_type);
            free(s->data.var);
            break;
        case SYMBOL_STRUCT:
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
            break;
        case SYMBOL_FONC:
            Param* p = s->data.fonc->params;
            while (p) {
                Param* tmp = p;
                p = p->next;
                free(tmp->type.nom_type);
                free(tmp);
            }
            free(s->data.fonc->return_type.nom_type);
            free(s->data.fonc);
            break;
    }
    free(s);
}
void free_table(Table* ht) {
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

/*Fonctions de recherche*/
static Symbol* ht_search_local(Table* ht, const char* key) {
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
        st = st->parent; // Remonte au parent
    }
    return NULL;
}

// Insertion d'un symbol dans une table de symbole
void ts_insert(SymbolTable* st, Symbol* sym, int ligne) {
    if (st->ht->count >= st->ht->size * 0.7) {      
        fprintf(stderr, "Erreur fatale : Table des symboles saturée (Niveau %d). "
                        "Augmentez HT_SIZE.\n", st->niveau);
        exit(1); 
    }
    if (ht_search_local(st->ht, sym->name) != NULL) {
        erreurs erreur=SYMBOLE;
        char * texte=str..."La variable a déjà été déclaré au niveau "+st->niveau;
        warning(erreur, ligne ,texte, sym->name)
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
    st->ht->count ++;
}