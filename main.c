#define YY_BUF_SIZE 16384
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "erreur.h"
#include "tablesymb.h"
#include "gestion_tables.h"
#include "affichage.h"
#include "gencode.h"
#include "y.tab.h"

extern int yyparse();
extern FILE* yyin;
extern int yylineno;
extern void yyrestart(FILE*);

/* Définition des variables globales */
SymbolTable* table_globale;
SymbolTable* table_courante;
SymbolTable* table_next;
ST_List* liste_tables;

int main(int argc, char **argv) {
    if (argc == 1) {
        fprintf(stderr, "Erreur : Il n'y a pas de fichiers à compiler.\n");
        return 1;
    }
    
    /* Création des listes */
    liste_tables = create_ST_list();
    Error_List* liste_erreur = create_error_list();

    table_globale = new_symbol_table(NULL, 0, 100);
    table_courante = table_globale;
    table_next = table_globale;
    
    // Premier passage : Analyse et compilation des fichiers
    for (int i = 1; i < argc; i++) {
        FILE* file = fopen(argv[i], "r");
        if (!file) {
            perror(argv[i]);
            continue;
        }
        
        table_courante = table_globale;
        table_next = table_globale;
        yyrestart(file); 
        
        printf("Analyse de %s...\n", argv[i]);
        int parse_result = yyparse();
        
        /* Traitement du résultat de l'analyse */
        if (parse_result == 0) {
            printf("\033[1;32m[SUCCESS]\033[0m Analyse de %s terminée avec succès.\n", argv[i]);
            
            // GÉNÉRATION AUTOMATIQUE DU NOM DU FICHIER BACKEND (_be)
            char* nom_origine = strdup(argv[i]);
            char* point = strrchr(nom_origine, '.');
            
            // Si le fichier possède l'extension ".c", on la retire temporairement
            if (point != NULL && strcmp(point, ".c") == 0) {
                *point = '\0';
            }
            
            // Allocation du nouveau nom : longueur(nom_sans_ext) + longueur("_be") + 1 pour '\0'
            char* nom_backend = malloc(strlen(nom_origine) + 4);
            if (nom_backend) {
                sprintf(nom_backend, "%s_be", nom_origine);
                printf("[GENCODE] Écriture du code à trois adresses dans : %s\n", nom_backend);
                
                // Appel de votre fonction définie dans gencode.c
                ecrire_quads_fichier(nom_backend);
                
                free(nom_backend);
            }
            free(nom_origine);
            
        } else {
            printf("\033[1;31m[FAILURE]\033[0m L'analyse de %s a échoué.\n", argv[i]);
            add_error_to_list(liste_erreur, argv[i]);
        }
        fclose(file);
    }
    
    add_to_ST_list(liste_tables, table_globale);
    
    // Second passage : Réanalyse des fichiers ayant échoué (gestion des conflits de définitions / EXTERN)
    Error_L* courant;
    for (courant = liste_erreur->first; courant != NULL; courant = courant->next) {
        FILE* file = fopen(courant->name, "r");
        if (!file) {
            perror(courant->name);
            continue;
        }
        
        table_courante = table_globale;
        table_next = table_globale;
        yyrestart(file); 
        
        printf("Réanalyse corrective de %s...\n", courant->name);
        int parse_result = yyparse();
        
        if (parse_result == 0) {
            printf("\033[1;32m[SUCCESS]\033[0m Analyse corrective terminée avec succès pour %s.\n", courant->name);
            
            // GÉNÉRATION DU NOM DU FICHIER BACKEND LORS DE LA RÉANALYSE
            char* nom_origine = strdup(courant->name);
            char* point = strrchr(nom_origine, '.');
            if (point != NULL && strcmp(point, ".c") == 0) {
                *point = '\0';
            }
            char* nom_backend = malloc(strlen(nom_origine) + 4);
            if (nom_backend) {
                sprintf(nom_backend, "%s_be", nom_origine);
                printf("[GENCODE] Écriture du code à trois adresses (correctif) dans : %s\n", nom_backend);
                ecrire_quads_fichier(nom_backend);
                free(nom_backend);
            }
            free(nom_origine);
        } else {
            printf("\033[1;31m[FAILURE]\033[0m L'analyse corrective de %s a également échoué.\n", courant->name);
        }
        fclose(file);
    }
    
    // Libération de la liste des erreurs accumulées
    free_error_list(liste_erreur);
    
    return 0;
}
