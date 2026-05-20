#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tablesymb.h"
#include "gestion_tables.h"

/* Helper pour l'indentation selon le niveau de portée */
void print_indent(int niveau) {
    for (int i = 0; i < niveau; i++) {
        printf("  ");
    }
}

/* Affiche les détails d'un type de donnée */
void afficher_datatype(DataType type) {
    printf("%s%s", type.nom_type, type.is_pointer ? "*" : "");
}

/* Affiche un symbole individuel */
void afficher_symbole(Symbol* s, int niveau) {
    if (!s) return;
    print_indent(niveau);
    
    switch (s->kind) {
        case SYMBOL_VAR:
            printf("[VAR] %s : ", s->name);
            afficher_datatype(s->data.var->type);
            if (s->data.var->is_extern) printf(" (EXTERN)");
            break;

        case SYMBOL_STRUCT:
            printf("[STRUCT] struct %s {", s->name);
            Field* f = s->data.str->champs;
            if (f) printf("\n");
            while (f) {
                print_indent(niveau + 1);
                printf("Field: %s (Type: ", f->name);
                afficher_datatype(f->type);
                printf(", Offset: %d)\n", f->offset);
                f = f->next;
            }
            if (s->data.str->champs) print_indent(niveau);
            printf("} (Size: %d)", s->data.str->taille_totale);
            break;

        case SYMBOL_FONC:
            printf("[FUNC] %s (", s->name);
            Param* p = s->data.fonc->params;
            while (p) {
                afficher_datatype(p->type);
                if (p->next) printf(", ");
                p = p->next;
            }
            printf(") -> ");
            afficher_datatype(s->data.fonc->return_type);
            if (s->data.fonc->is_extern) printf(" (EXTERN)");
            break;
    }
    printf("\n");
}

/* Affiche une table de hachage (le contenu d'une portée) */
void afficher_table_hachage(Table* ht, int niveau) {
    if (!ht) return;
    for (int i = 0; i < ht->size; i++) {
        if (ht->items[i] != NULL) {
            // On ignore le symbole "_" interne si nécessaire
            if (strcmp(ht->items[i]->key, "_") != 0) {
                afficher_symbole(ht->items[i]->symbol, niveau);
            }
        }
    }
}

/* Affiche récursivement une SymbolTable et ses enfants via le pointeur 'next' ou 'parent' */
void afficher_symbol_table(SymbolTable* st) {
    if (!st) return;

    printf("\n");
    print_indent(st->niveau);
    printf("=== PORTÉE NIVEAU %d ===\n", st->niveau);
    
    afficher_table_hachage(st->ht, st->niveau);

    // Si vous gérez une liste linéaire de tables via st->next
    if (st->next) {
        afficher_symbol_table(st->next);
    }
}

/* Affiche la liste des tables (ST_List) issue de la compilation de plusieurs fichiers */
void afficher_liste_tables(ST_List* liste) {
    printf("\n==========================================\n");
    printf("   VISUALISATION DE LA LISTE DES TABLES\n");
    printf("==========================================\n");
    
    if (!liste || !liste->first) {
        printf("La liste des tables est vide.\n");
        return;
    }

    ST* courant = liste->first;
    int f_idx = 1;
    while (courant) {
        printf("\n--- Fichier/Unité #%d ---", f_idx++);
        afficher_symbol_table(courant->table);
        courant = courant->next;
    }
}

/* Affiche la liste des erreurs */
void afficher_liste_erreurs(Error_List* list_ptr) {

    printf("\n==========================================\n");
    printf("   RAPPORT D'ERREURS (Fichiers échoués)\n");
    printf("==========================================\n");

    if (!list_ptr|| list_ptr->count == 0) {
        printf("\033[1;32mAucune erreur détectée.\033[0m\n");
        return;
    }

    printf("Nombre d'échecs : %d\n", list_ptr->count);
    Error_L* courant = list_ptr->first;
    while (courant) {
        printf("  - [ECHEC] %s\n", courant->name);
        courant = courant->next;
    }
}