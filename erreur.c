#include <stdlib.h>
#include <stdio.h>

enum erreurs {
    LEXICALE,
    SYNTAXE,
    SEMANTIQUE,
    SYMBOLE,
    POINTEUR,
    FLOTTANT,
};

static void affiche_type(enum erreur){
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
        case SYMBOLE:
            printf("Error during the management of the symbols");
            break;
        case POINTEUR : 
            printf("Pointer error");
            break;
        case FLOTTANT : 
            printf("Float error");
            break;
        default :
            break;
    }
};

static void afficher_erreur(void){
    char * couleur_rouge  = "\033[1;31m";
    printf("%sErreur d'exécution [%s",couleur_rouge,couleur_rouge);
    affiche_Type(TYPE_ERREUR);
    printf("%s] :  %s\n",couleur_rouge,couleur_rouge);
    printf("%sLigne fautive : \"%s\"%s\n",couleur_rouge,LIGNE,couleur_rouge);
    printf("%sValeur fautive : %s",couleur_rouge,couleur_rouge);
    printf("%s\n",TEXTE_ERREUR);
    printf("%sMessage : %s%s\n",couleur_rouge,MESSAGE_ERREUR,couleur_rouge);
};

static void afficher_warning(void){
    char * couleur_jaune  = "\033[1;33m";
    printf("%sWarning [%s",couleur_jaune,couleur_jaune);
    affiche_Type(TYPE_ERREUR);
    printf("%s] :  %s\n",couleur_jaune);
    printf("%sLigne fautive : \"%s\"%s\n",couleur_jaune,LIGNE,couleur_jaune);
    printf("%sValeur fautive : %s",couleur_jaune,couleur_jaune);
    printf("%s\n",TEXTE_ERREUR);
    printf("%sMessage : %s%s\n",couleur_jaune,MESSAGE_ERREUR,couleur_jaune);
};

void erreur(enum erreurs type, int ligne,const char* explication, char* s){
    TYPE_ERREUR=type;
    LIGNE=ligne;
    MESSAGE_ERREUR=explication;
    TEXTE_ERREUR=s;
    afficher_erreur();
    exit(1);
};

void warning(enum erreurs type, int ligne,const char* explication, char* s){
    TYPE_ERREUR=type;
    LIGNE=ligne;
    MESSAGE_ERREUR=explication;
    TEXTE_ERREUR=s;
    afficher_warning();
};