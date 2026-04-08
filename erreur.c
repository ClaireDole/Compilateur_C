#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "erreur.h"

enum erreurs TYPE_ERREUR;
int LIGNE;
char MESSAGE_ERREUR[512];
char TEXTE_ERREUR[512];

static void affiche_type(enum erreurs erreur){
    switch(erreur){
        case LEXICALE:
            printf("Lexical error");
            break;
        case SYNTAXE:
            printf("Syntaxical error");
            break;
        case SEMANTIQUE:
            printf("Semantical error");
            break;
        default :
            break;
    }
}

/* Enlever 'static' pour correspondre à la déclaration dans le .h */
void afficher_erreur(void){
    char * couleur_rouge  = "\033[1;31m";
    printf("%sErreur d'exécution [%s",couleur_rouge,couleur_rouge);
    affiche_type(TYPE_ERREUR);
    printf("%s] :  %s\n",couleur_rouge,couleur_rouge);
    printf("%sLigne fautive : %d%s\n",couleur_rouge,LIGNE,couleur_rouge);
    printf("%sValeur fautive : %s",couleur_rouge,couleur_rouge);
    printf("%s\n",TEXTE_ERREUR);
    printf("%sMessage : %s%s\n",couleur_rouge,MESSAGE_ERREUR,couleur_rouge);
}

/* Enlever 'static' pour correspondre à la déclaration dans le .h */
void afficher_warning(void){
    char * couleur_jaune  = "\033[1;33m";
    printf("%sWarning [%s",couleur_jaune,couleur_jaune);
    affiche_type(TYPE_ERREUR);
    printf("%s] :  %s\n",couleur_jaune,couleur_jaune);
    printf("%sLigne fautive : %d%s\n",couleur_jaune,LIGNE,couleur_jaune);
    printf("%sValeur fautive : %s",couleur_jaune,couleur_jaune);
    printf("%s\n",TEXTE_ERREUR);
    printf("%sMessage : %s%s\n",couleur_jaune,MESSAGE_ERREUR,couleur_jaune);
}

void erreur(enum erreurs type, int ligne, const char* explication, char* s){
    TYPE_ERREUR = type;
    LIGNE = ligne;
    snprintf(MESSAGE_ERREUR, sizeof(MESSAGE_ERREUR), "%s", explication);
    snprintf(TEXTE_ERREUR, sizeof(TEXTE_ERREUR), "%s", s);
    afficher_erreur();
    exit(1);
}

void warning(enum erreurs type, int ligne, const char* explication, char* s){
    TYPE_ERREUR = type;
    LIGNE = ligne;
    snprintf(MESSAGE_ERREUR, sizeof(MESSAGE_ERREUR), "%s", explication);
    snprintf(TEXTE_ERREUR, sizeof(TEXTE_ERREUR), "%s", s);
    afficher_warning();
}
