#ifndef ERREUR_H
#define ERREUR_H
enum erreurs {
    LEXICALE;
    SYNTAXE;
    SEMANTIQUE;
};
void afficher_erreur(void);
void erreur(enum erreurs type, char* fonction, char* explication, sexpr s);
#endif