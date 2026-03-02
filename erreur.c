#include <stdlib.h>
#include <stdio.h>

enum erreurs {
    LEXICALE;
    SYNTAXE;
    SEMANTIQUE;
};

void affiche_type(enum erreur){
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
};

void afficher_erreur(void){
    char * couleur_rouge  = "\033[1;31m";
    printf("%sErreur d'exécution [%s",couleur_rouge,couleur_rouge);
    affiche_Type(TYPE_ERREUR);
    printf("%s] :  %s\n",couleur_rouge,couleur_rouge);
    printf("%sLigne fautive : \"%s\"%s\n",couleur_rouge,LIGNE,couleur_rouge);
    printf("%sValeur fautive : %s",couleur_rouge,couleur_rouge);
    printf("%s\n",TEXTE_ERREUR);
    printf("%sMessage : %s%s\n",couleur_rouge,MESSAGE_ERREUR,couleur_rouge);
    exit(1)
}:

void erreur(enum erreurs type, int ligne,char* explication, char* s){
    TYPE_ERREUR=type;
    LIGNE=ligne;
    MESSAGE_ERREUR=explication;
    TEXTE_ERREUR=s;
    afficher_erreur()
};