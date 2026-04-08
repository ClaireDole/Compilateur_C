#include <stdio.h>
#include <stdlib.h>
#include "y.tab.h"
#include "erreur.h"
#include "tablesymb.h"

extern int yyparse();
extern FILE* yyin;
extern int yylineno;

/* Définition des variables globales */
SymbolTable* table_globale;
SymbolTable* table_courante;

/* Fonction principale */
int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <fichier_source.c>\n", argv[0]);
        return 1;
    }

    /* Ouverture du fichier source */
    FILE *f = fopen(argv[1], "r");
    if (!f) {
        perror("Erreur lors de l'ouverture du fichier");
        return 1;
    }

    /* Création de la table des symboles globale (niveau 0) */
    table_globale = new_symbol_table(NULL, 0, 100);
    if (!table_globale) {
        fprintf(stderr, "Erreur: Impossible de créer la table des symboles globale\n");
        fclose(f);
        return 1;
    }
    table_courante = table_globale;

    /* Configuration de l'analyseur lexical */
    yyin = f;
    yylineno = 1;

    /* Lancement de l'analyse syntaxique et sémantique */
    int parse_result = yyparse();

    /* Affichage du résultat */
    if (parse_result == 0) {
        printf("\033[1;32m[SUCCESS]\033[0m Analyse terminée avec succès.\n");
    } else {
        printf("\033[1;31m[FAILURE]\033[0m L'analyse a échoué.\n");
    }

    /* Nettoyage */
    fclose(f);
    
    /* Libération de la mémoire */
    if (table_globale) {
        del_symbol_table(table_globale);
    }
    
    return parse_result;
}