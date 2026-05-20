# Documentation justificative des modifications apportées

## Projet de compilation
Auteures : Claire Dole, Maëlle Robert

## Introduction

Ce document présente d'abord les différences avec les fichiers fournis ainsi que les choix d'implémentation des différentes étapes. Les étapes sont dans l'ordre de fonctionnement d'un compilateur. 
Puis une section exposant les difficultés rencontrées lors de la programmation suivi du fonctionnement du compilateur à la fin du projet. Et enfin une conclusion de chacune concernant ses acquis lors du projet et ses ressentis.
Répartition du travail : 
    - Claire : analyseur lexical de STRUCIT-FRONTEND / conception et gestion de la table des symboles / actions sémantiques (système de typage et gestion des erreurs) / main
    - Maëlle : grammaire de STRUCIT-FRONTEND / analyseur lexical de STRUCIT-BACKEND /grammaire de STRUCIT-BACKEND / génération de code / Makefile
Nous avons fait le choix dans main.c d'utiliser une compilation multi-passes minimale : les fichiers ayant échoué lors de la première passe sont ré-analysés une seconde fois. Cela permet de résoudre les problèmes de dépendances croisées (comme l'utilisation de mots-clés EXTERN faisant référence à des structures ou fonctions définies plus tard dans un autre fichier).
Aide et ressources utilisés : nous avons utilisé une IAg (le détail de cette utilisation est dans le fichier IAg.txt) ainsi que des sites internets : 
    - Claire : Stackoverflow (https://stackoverflow.com/questions) et Zeste de savoir (https://zestedesavoir.com/tutoriels/755/le-langage-c-1/)
    - Maëlle : Zeste de savoir (https://zestedesavoir.com/tutoriels/755/le-langage-c-1/)
Organisation de l'archive : 
    - les fichiers tests sont dans le répertoire tests
    - lexeur_fe.lex : analyseur lexicale pour le langage STRUCIT-Frontend
    - structefe_no_actions.y : fichier bison pour le langage STRUCIT-Frontend (contenant donc les actions sémantiques du compilateur)
    - affichage.c : contient les fonctions d'affichage de la table de symbole
    - tablesymb.c : contient l'implémentation et les fonctions de bases de l'architecture de la table de symbole
    - gestion_tables.c : contient des fonctions de contrôle de types, de comparaison de types, d'entrée et de sortie de scope (table des symboles) ainsi que des fonctions et des structures permettant de gérer les   informations sémantiques
    - erreur.c : contient des fonctions permettant de gérer les erreurs et les warnings
    - gencode.c : génération de code à trois adresses (quads) et écriture du fichier backend
    - lexeur_be.lex : analyseur lexical Flex pour le langage STRUCIT-Backend
    - structbe : grammaire Bison pour STRUCIT-Backend (validation syntaxique uniquement)
    - main.c : fichier principal du programme
    - Makefile : pour faciliter la compilation
    - les fichiers .h (headers) de plusieurs fichiers sources .c

## Modifications de l’analyseur lexical (`lexeur_fe.lex`)

### Mots clés conservés et supprimés

- `extern`, `for`, `while`, `if`, `else`, `return`, `sizeof`, `int`, `void`, `struct` sont **conservés** (seuls mots clés autorisés)
- `auto`, `break`, `case`, `char`, `const`, `continue`, `default`, `do`, `double`, `enum`, `float`, `goto`, `long`, `register`, `short`, `signed`, `static`, `switch`, `typedef`, `union`, `unsigned`, `volatile` sont **supprimés** (hors langage)

### Constantes

- Hexadécimaux `0[xX]{H}+{IS}?` fait un **rejet avec erreur** car on veut uniquement **base 10**
- Octaux `0{D}+{IS}?` fait un **rejet avec erreur** car on veut uniquement **base 10**
- Flottants `{D}+{E}{FS}?`, `{D}*"."...`, `{D}+"."...` font un **rejet avec erreur** (uniquement **constantes entières**)
- Décimaux `{D}+{IS}?` est  **conservé** (`return CONSTANT`)

### Chaînes et caractères

- Chaînes `L?\"(\\.|[^\\"])*\"` est **supprimé**
- Caractères `L?'(\\.|[^\\'])+'` est **supprimé** 

### Opérateurs

#### Opérateurs unaires

- `-` : Moins unaire (changement de signe), il est gardé
-  `&` : Adresse d’une variable ou d’une fonction, il est gardé car autorisé sur variable int ou fonction
- `*` : Déréférencement d’un pointeur, il est gardé
- `++` : Incrémentation, il est supprimé car non mentionné dans le sujet
- `--` : Décrémentation, il est supprimé car non mentionné dans le sujet

#### Opérateurs binaires arithmétiques

- `+` : Addition / arithmétique des pointeurs, il est gardé car autorisé sur int et pointeurs
- `-` : Soustraction / arithmétique des pointeurs, il est gardé car autorisé entre pointeurs ou pointeur/int
- `*` : Multiplication, il est gardé car autorisée sur int uniquement
- `/` : Division, il est gardé car autorisée sur int uniquement
- `%` : Modulo, il est supprimé car non mentionné, il est hors langage

#### Opérateurs relationnels et de comparaison

- `<` : Inférieur, il est gardéacr les six opérateurs de comparaison sont disponibles
- `>` : Supérieur, il est gardé
- `<=` : Inférieur, il est gardé
- `>=` : Supérieur ou égal, il est gardé
- `==` : Égal, il est gardé
- `!=` : Différent, il est gardé

#### Opérateurs logiques

- `&&` : ET logique, il est gardé car les deux opérateurs booléens sont && et ||
- `||` : OU logique, il est gardé

#### Opérateurs d’accès et de structure

-  `->` : Accès à un champ via pointeur de structure, il est gardé car "->champ retourne le champ pointé par un pointeur"
- `.` : Accès direct à un champ, retourne une erreur car les structures sont manipulées uniquement par pointeur –> opérateur `.` interdit ("Les structures ne sont manipulables que par pointeur, opérateur . incorrect. Merci d’utiliser ->")

#### Opérateurs d’affectation composites

-  `=` : Affectation simple, il est gardé
-  `+=`, `-=`, `*=`, `/=`, `%=` : Affectation avec opération, ils sont supprimés car non mentionnés –> langage restreint aux affectations simples
-  `<<=`, `>>=`, `&=`, `^=`, `|=` : Affectation bit à bit, ils sont supprimés (opérateurs bit à bit non autorisés)

#### Opérateurs de décalage et bit à bit

- `<<` : Décalage gauche, il est supprimé car non mentionné –> hors langage
- `>>` : Décalage droit, il est supprimé car non mentionné –> hors langage
- `&` (binaire) : ET bit à bit, il est supprimé car seul le `&` unaire (adresse) est autorisé
- `\|` : OU bit à bit, il est supprimé car non mentionné –> hors langage
- `^` : XOR bit à bit, il est supprimé car non mentionné –> hors langage
- `~` : Complément bit à bit, il est supprimé car non mentionné –> hors langage

#### Opérateurs divers

- `(...)` : Appel de fonction, il est gardé car nécessaire pour les appels de fonction
- `[...]` : Indice de tableau, il est supprimé car les tableaux ne sont pas autorisés
- `? :` : Opérateur ternaire, il est supprimé car non mentionné –> hors langage
- `,` : Virgule (séquence), il est gardé car il est tilisé dans les listes de déclarations et d’arguments
- `;` : Fin d’instruction, il est gardé (nécessaire)
- `{}` : Blocs, il est gardé car il est nécessaire pour les blocs d’instructions
- `...` : Variadique retourne un erreur, il n'est pas mentionné –> interdit ("Les fonctions variadiques (...) ne sont pas supportees.")

#### Résumé des motifs supprimés des opérateurs

- Non mentionné dans le sujet : `++`, `--`, `%`, `+=`, `-=`, `*=`, `/=`, `%=`, `<<`, `>>`, `<<=`, `>>=`, `&` binaire, `\|`, `^`, `~`, `? :`, `[...]` |
- Interdit explicitement : `.` (point seul), `...` (variadique)
- Hors du sous‑langage défini : Tous les opérateurs bit à bit, d’incrémentation, d’affectation composée


### Commentaires

- Non gérés : Gestion complète des `/* ... */` avec détection de commentaire non fermé
- Absent : Ajout des commentaires `//[^\n]*` (ignorés)

### Gestion des erreurs lexicales

- **Règle finale** : tout caractère non reconnu déclenche `erreur(LEXICALE, ...)`
- **Conforme au sujet** : "tout autre token qui n’appartient pas au langage doit être négligé" (ici : signalé comme erreur)

## Modifications de l’analyseur syntaxique (`structfe_no_actions.y`)

### Différences au niveau des règles grammaticales

### 1. Ajout de `%union` et typage des non-terminaux

**Grammaire fournie :**  
Aucune `%union`, pas de typage des non-terminaux. Les valeurs sémantiques ne sont pas structurées.

**Grammaire finale :**  
Ajout d'une `%union` complète et de `%type` pour chaque non-terminal. Cela permet de propager des informations structurées (nom, type, état, listes de paramètres, etc.) de la feuille vers la racine, indispensable pour les actions sémantiques et la génération de code.

### 2. Transformation de `declaration`

`declaration_specifiers declarator ';'` => `declaration_specifiers init_declarator_list ';'` |
`struct_specifier ';'` => *(supprimé, fusionné avec la règle précédente)* |

**Justification :**  
La grammaire fournie ne permettait qu’une seule variable par déclaration. Le sujet page 3 autorise les déclarations multiples (ex: `int a, *b, c;`). L’introduction de `init_declarator_list` permet de gérer une liste de déclarateurs séparés par des virgules.  
La règle `struct_specifier ';'` est redondante : un `struct_specifier` est déjà un `type_specifier` dans `declaration_specifiers` donc elle a été supprimée.

### 3. Ajout de `EXTERN` dans une règle dédiée

`declaration_specifiers : EXTERN type_specifier` => `external_declaration : EXTERN declaration_specifiers init_declarator_list ';'`

**Justification :**  
Dans la grammaire fournie, `EXTERN` était traité au sein de `declaration_specifiers`. Cela rendait difficile la distinction sémantique entre une déclaration externe et une définition normale. En déplaçant `EXTERN` dans une règle séparée au niveau `external_declaration`, on peut appliquer des vérifications spécifiques (ex: interdire les initialisations, gérer les déclarations de fonctions externes, etc.).

### 4. Transformation de `struct_declaration`

`type_specifier declarator ';'` => `type_specifier struct_declarator_list ';'`

**Justification :**  
Les champs d’une structure peuvent également être multiples (ex: `int a, *b, c;`). `struct_declarator_list` joue le même rôle que `init_declarator_list` pour les champs.

### 5. Ajout de `struct_declarator_list` et `init_declarator_list`

**Grammaire fournie :**  
Ces règles n’existaient pas.

**Grammaire finale :**  
```
init_declarator_list : declarator | init_declarator_list ',' declarator
struct_declarator_list : declarator | struct_declarator_list ',' declarator
```

**Justification :**  
Elles permettent les déclarations multiples respectivement pour les variables globales/locales et pour les champs de structure.

### 6. Modification de `declarator` et `direct_declarator` pour gérer les pointeurs de fonction

**Grammaire fournie :**  
```
declarator : '*' direct_declarator | direct_declarator
direct_declarator : IDENTIFIER | '(' declarator ')' | direct_declarator '(' parameter_list ')' | direct_declarator '(' ')'
```

**Grammaire finale :**  
Mêmes règles, mais avec ajout d’attributs (`state`, `is_pointer`, `param_list`) dans la `%union` pour distinguer :
- `state=0` : variable simple
- `state=1` : pointeur simple
- `state=3` : pointeur entre parenthèses (pour `(*p)`)
- `state=4` : fonction (ou prototype)
- `state=5` : pointeur de fonction

**Justification :**  
La grammaire seule ne suffit pas à distinguer `int *f();` (fonction retournant un pointeur) de `int (*f)();` (pointeur de fonction). Les attributs `state` permettent de propager cette information lors de l’analyse descendante.

### 7. Ajout de `%glr-parser` et `%nonassoc IFX`

**Grammaire fournie :**  
Pas de directive particulière. L’ambiguïté du `if ... else` génère un conflit shift/reduce.

**Grammaire finale :**  
```
%nonassoc IFX
%nonassoc ELSE
%glr-parser
```

**Justification :**  
`%glr-parser` active l’algorithme GLR qui peut gérer les grammaires ambiguës. Couplé à `%nonassoc IFX` et `%nonassoc ELSE`, on résout l’ambiguïté classique du `if ... else` sans conflit.

### 8. Ajout des parenthèses obligatoires pour `sizeof`

**Grammaire fournie :**  
`SIZEOF unary_expression`

**Grammaire finale :**  
```
SIZEOF '(' unary_expression ')'
| SIZEOF '(' type_specifier ')'
```

**Justification :**  
Le C standard impose des parenthèses pour `sizeof(type)` mais les rend optionnelles pour `sizeof expression`. Pour simplifier l’analyse sémantique et la génération de code, nous avons imposé les parenthèses dans les deux cas.

### 9. Suppression de l’opérateur `.` dans `postfix_expression`

**Grammaire fournie :**  
`postfix_expression '.' IDENTIFIER`

**Grammaire finale :**  
Règle supprimée. Seul `postfix_expression PTR_OP IDENTIFIER` (`->`) est conservé.

**Justification :**  
Le sujet page 3 stipule : *" Les structures ne peuvent être manipulées que par le biais de pointeurs. "* L’opérateur `.` est donc interdit.

### 10. Ajout des constructions itératives `FOR` et `WHILE`

**Grammaire fournie :**  
Seulement `WHILE`.

**Grammaire finale :**  
```
iteration_statement
    : FOR '(' expression_statement expression_statement expression ')' statement
    | WHILE '(' expression ')' statement
```

**Justification :**  
Le sujet demande la gestion de `for` et `while`.

### 11. Ajout des mid‑rules pour la gestion des labels en génération de code

**Grammaire fournie :**  
Aucune règle intermédiaire.

**Grammaire finale :**  
Dans `selection_statement` et `iteration_statement`, des actions insèrent des `new_label()` pour créer les labels nécessaires aux sauts conditionnels et inconditionnels.

**Justification :**  
Pour générer du code trois adresses avec des structures de contrôle (`if`, `if-else`, `while`, `for`), il faut créer des labels intermédiaires. Les mid‑rules permettent d’émettre ces labels au bon moment pendant l’analyse.

### 12. Ajout de `compound_statement_fonction`

**Grammaire fournie :**  
`function_definition : declaration_specifiers declarator compound_statement`

**Grammaire finale :**  
`compound_statement_fonction` est une copie de `compound_statement` mais sans gestion de nouvelle portée (l’entrée de portée est gérée dans `function_definition` avant le corps).

**Justification :**  
Dans une fonction, les paramètres doivent être insérés dans la table des symboles **avant** l’ouverture du bloc corps. `compound_statement` normal gère sa propre entrée de portée. Il a fallu créer une variante qui n’ouvre pas de nouvelle portée.

## Règles strictement identiques entre les deux grammaires

Les règles suivantes n’ont pas changé (seules les actions sémantiques diffèrent) :

- `program`, `external_declaration`
- `type_specifier` (`VOID`, `INT`, `struct_specifier`)
- `struct_specifier` (les trois formes : `STRUCT IDENTIFIER '{' ... '}'`, `STRUCT '{' ... '}' IDENTIFIER`, `STRUCT IDENTIFIER`)
- `struct_declaration_list` (récursivité)
- `parameter_list`, `parameter_declaration` (la forme avec `declaration_specifiers declarator`)
- `primary_expression` (`IDENTIFIER`, `CONSTANT`, `'(' expression ')'`)
- `argument_expression_list`
- `multiplicative_expression`, `additive_expression`
- `relational_expression`, `equality_expression`
- `logical_and_expression`, `logical_or_expression`
- `expression`, `assignment_expression` (la structure générale)
- `statement`, `compound_statement`, `declaration_list`, `statement_list`
- `expression_statement`
- `jump_statement` (`RETURN`)
- `function_definition` (structure générale)

## Ce qui a été supprimé

`declaration : struct_specifier ';'` car redondante 
`postfix_expression '.' IDENTIFIER` car opérateur `.` interdit 
`declaration_specifiers : EXTERN type_specifier` acr déplacée au niveau `external_declaration` 

## Ce qui a été ajouté

`init_declarator_list` : Déclarations multiples de variables 
`struct_declarator_list` : Déclarations multiples de champs 
`open_scope` : Gestion explicite de l’entrée de portée 
`compound_statement_fonction` : Variante sans ouverture de portée pour les fonctions 
`FOR` dans `iteration_statement` : Boucle `for` 
`%glr-parser`, `%nonassoc IFX` : Levée ambiguïté `if ... else` 
`SIZEOF '(' type_specifier ')'` : `sizeof` sur type (avec parenthèses obligatoires) 
Mid‑rules dans `selection_statement` et `iteration_statement` : Émission des labels pour génération de code 

## Architecture de la table des symboles
L'implémentation choisie repose sur une structure de table de hachage avec adressage ouvert et double hachage pour minimiser les collisions. On utilise également une liste chaînée de tables pour permettre la gestion des niveaux de portées.
### Structuration des blocs
Pour gérer la visibilité des variables (locales vs globales) et les blocs imbriqués { }, les tables des symboles sont organisées en une structure arborescente ( liste chaînée inversée) :
SymbolTable : Contient un pointeur vers sa table de hachage locale (ht), un pointeur vers la portée parente (parent), et son niveau d'imbrication (niveau).
Mécanisme de Scope :
    - enter_scope() : Crée une nouvelle table, incrémente le niveau sémantique, et met à jour la table_courante.
    - exit_scope() : Remonte d'un cran en réassignant table_courante = table_courante->parent.
La liste des tables (ST_List) est introduite dans main.c, elle compile l'ensemble des tables globales générées lorsque le compilateur traite une liste de plusieurs fichiers sources.
### Représentation des symboles
Chaque entrée dans la table possède une catégorie (SymbolKind) qui détermine l'interprétation de ses données de manière polymorphe via une union (data).
    - SYMBOL_VAR VarInfo (Type, is_pointer, is_extern) Variables scalaires et pointeurs.
    - SYMBOL_STRUCT StructInfo (Nom, liste de champs, taille totale, nb_champs) Définitions de types structures.
    - SYMBOL_FONC FoncInfo (Type de retour, paramètres, is_extern) Fonctions et prototypes.
### Algo de recherche
ts_lookup (Recherche Lexicale/Ascendante) : Cherche un identifiant dans la portée courante. S'il n'est pas trouvé, il remonte de manière itérative vers la portée parente (st->parent) jusqu'à la portée globale.
global_lookup : Parcourt l'intégralité des tables disponibles à travers différents fichiers ou contextes compilés (gestion des variables multi-fichiers).
### Choix de gestion de la taille des tables
Dans la fonction ts_insert, nous faisons le choix de faire une erreur fatale si la table de hachage est remplie à plus  de 70%, cela correspond au load factor de la fonction de hachage.
En effet, dans le cadre d’un langage réduit comme pour ce projet, il n’y aura pas énormément de symboles à gérer. Puisque l’implémentation du resizing est complexe et donc source de bugs potentiels nous avons préféré faire sans le resizing.
### Affichage
Afin de faciliter le débuggage et de pouvoir vérifier rapidement la validité d'une analyse réussie nous avons mis en place un système d'affichage des tables de symboles. 
Ainsi l'utilisateur du compilateur peut profiter d'une représentation visuelle des tables de symboles de son programme à compiler et peut facilement corriger des erreurs au besoin.
### Structures de données utilisées

#### Types de symboles
    énumération symbol_type : SYMBOL_VAR, SYMBOL_STRUCT, SYMBOL_FONC
####  Type de données 
    structure DataType : nom_type (char*), is_pointer (int)
#### Paramètres d'une fonction
    structure Param : name (char*), type (DataType), next (Param*)
#### Champs d'une fonction
    structure Field : name (char*), type (DataType), offset (int), next (Field*)
#### Informations d'une entité
    Variable : structure VarInfo : type (DataType), is_extern (int)
    Fonction : structure FoncInfo : return_type (DataType), nb_params (int), params (Param*), is_extern (int)
    Structure : structure StructInfo : nom (char*), nb_champs (int), champs (Field*), taille_totale (int), is_extern (int)
#### Informations d'un symbole
    structure Symbol : name (char*), kind (symbol_type), data (union(VarInfo, FoncInfo, StructInfo))
#### Entrée dans la table des symboles
    structure Item : key (char*), symbol (Symbol*)
#### Table de hachage
    structure Table : size (int), count (int), items (Item**)
#### Table des symboles
    structure SymbolTable : ht (Table*), niveau (int), parent(SymbolTable*), next(SymbolTable*)
#### Liste de tables des symboles
    structure ST : table (SymbolTable*), next (ST*)
    structure ST_List : first (ST*), last (ST*), count (int)

## Typage et actions sémantiques fondamentales

### Système de typage
Le compilateur applique des règles de typage fortes à l'aide de la fonction datatype_comp.
On applique la manipulation par pointeurs obligatoire, les structures ne peuvent être manipulées que via des pointeurs (is_pointer == 1). 
Toute déclaration de variable de type structure directe (non-pointeur) lève une erreur sémantique.
De plus, les pointeurs de pointeurs sont interdits : le système vérifie lors de l'analyse du déclarateur * direct_declarator si le sous-élément est déjà un pointeur, bloquant les types comme int.
Contraintes sur le type void : les variables de type void sont interdites, tout comme l'utilisation du pointeur générique void*. En effet, le pointeur générique n’est pas mentionné explicitement dans la liste des pointeurs autorisés et pose problème avec l’arithmétique des pointeurs. Son unique utilisation est lorsqu'une fonction avec un type retour valant void est pointée par un pointeur de fonction.

### Pointeurs de fonction
Signature "Fantôme" : Lorsqu'un pointeur de fonction est déclaré (ex: int (*f)(int)), le compilateur génère en tâche de fond une fonction anonyme unique nommée "0_i" (où i est un compteur).
Cette signature est insérée dans la table des symboles.
La variable utilisateur (f) est alors enregistrée comme une SYMBOL_VAR standard, mais son type pointe vers l'identifiant "0_i".
Lors d'une déclaration multiple, le compilateur utilise function_comp pour comparer les signatures et s'assurer que les pointeurs déclarés sur la même ligne partagent exactement les mêmes types d'arguments et de retour.

## Vérifications contextuelles et contrôle de cohérence
Les fonctions de validation de haut niveau sont dans le fichier gestion_tables.c.
### Affectations et L-Values
Lors d'une réduction d'une règle d'affectation (unary_expression '=' assignment_expression), l'analyseur vérifie l'état (state) de l'expression de gauche :
    - elle doit obligatoirement être une L-value modifiable (identifiant de variable, accès à un champ de structure via ->, ou pointeur déréférencé *ptr).
    - les constantes et les noms de fonctions directs sont rejetés.
    - les types des membres gauche et droit doivent être rigoureusement identiques (datatype_comp == 0).

### Appels de Fonctions (postfix_expression '(' ... ')')
check_function_call_with_args : Vérifie d'abord si l'identifiant appelé existe et s'il s'agit bien d'une fonction (ou d'un pointeur de fonction valide).
Validation des arguments : Le nombre d'arguments fournis à la syntaxe doit correspondre au champ nb_params du symbole. Ensuite, une boucle itère simultanément sur la liste des arguments (ArgList) et la liste des paramètres (ParamList) pour valider leur compatibilité de type un à un.

### Accès aux Structures (PTR_OP : ->)
Lorsqu'un accès de type structure->champ est rencontré :
    - le membre de gauche est analysé pour vérifier qu'il est bien un pointeur et qu'il pointe vers une structure déclarée.
    - la liste chaînée des champs (Field*) de la structure est parcourue linéairement. Si le nom correspond, le type du champ est propagé à l'expression globale. Sinon, une erreur "Champ non trouvé" est levée.

### Analyse des Instructions de Retour (RETURN)
Le compilateur suit de près le flux d'exécution au sein des fonctions : à chaque fois qu'une instruction RETURN est croisée, son type est ajouté à une StatementList.
Dans la règle function_definition, le compilateur vérifie le flag unique. Si deux return au sein du même corps de fonction renvoient des types différents, une erreur sémantique est déclenchée.
Enfin, le type effectif du return est comparé avec le prototype de la fonction (type_attendu).

### Structures de données utilisées

#### Liste de paramètres
    structure ParamList : first(Param*), last (Param*), count (int)
#### Liste de champs
    structure FieldList : first(Field*), last (Field*), count (int)
#### Liste d'arguments
    structure Arg : is_pointer(int), name (char*), state (int), next (Arg*), type (DataType)
    structure ArgList : first(Arg*), last (Arg*), count (int)
#### Liste de variables et/ou de pointeurs de fonction
    structure Point : is_pointer (int), name (char*), params (Param*), state (int), next (Point*)
    structure PointList : first(Point*), last (Point*), count (int)
#### Liste de statement (pour le type de retour d'un bloc)
    structure Statement : unique (int), ret_type (DataType), next(Statement*)
    structure StatementList : first(Statement*), last (Statement*), count (int)
#### Liste des noms de fichiers n'ayant pas été validé lors de la première passe
    structure Error_L : name(char*), next (Error_L*)
    structure ErrorList : first(Error_L*), last (Error_L*), count (int)

## Gestion des erreurs sémantiques
Les erreurs sont gérées par une fonction erreur dans le fichier erreurs.c.
On a également la présence de warning, gérés par une fonction warning dans le fichier erreurs.c.
Ces fonctions sont appelées aux endroit nécessaire soit dans les actions sémantiques soit dans des fonctions annexes.

## Génération de code (`gencode.c`)

La génération de code produit un code à trois adresses dans le langage STRUCIT-backend. Chaque instruction générée est stockée sous forme de quadruplet `(op, res, arg1, arg2)` dans un tableau global `table_quads`, puis sérialisée dans un fichier via `ecrire_quads_fichier`.

### Schémas de traduction

#### Déclarations de variables

```
DEC <nom> <type>
```
Exemple : `int x;` => `DEC x int`  
Exemple : `extern int x;` => `extern DEC x int`

#### Définitions de fonctions

```
FUNC <nom>:
  <nom_param> = PARAM
  ...
  <corps>
END_FUNC <nom>
```
Chaque paramètre formel est récupéré avec un quad `PARAM_FETCH`. La définition se termine toujours par un quad `FUNC_END`.

#### Prototypes de fonctions

```
PROTO <nom> <type_retour>
  PARAM_TYPE <type_param>
  ...
```

#### Affectation simple (`x = y`)

```
COPY x y
```

#### Affectation depuis une constante (`x = 42`)

```
ASSIGN x 42
```

#### Opérations arithmétiques binaires (`x = y op z`)

Les quatre opérateurs `+`, `-`, `*`, `/` suivent le schéma général à trois adresses :
```
t0 = y + z => quad("+", "t0", "y", "z")
t1 = t0 * w => quad("*", "t1", "t0", "w")
```
Les temporaires sont introduits par `new_temp()`.

#### Négation unaire (`x = -y`)

```
NEG x y
```

#### Prise d'adresse (`x = &y`)

```
ASSIGN_ADDR x y
```

#### Déréférencement en lecture (`x = *p`)

```
LOAD x p
```

#### Déréférencement en écriture (`*p = x`)

```
STORE p x
```

#### Accès à un champ de structure (`x = p->champ`)

```
GET_FIELD x p champ
```

#### Appel de fonction sans récupération de valeur

```
PARAM <arg1>
PARAM <arg2>
...
CALL <nom_fonction>
```

#### Appel de fonction avec récupération de valeur (`res = f(a, b)`)

```
PARAM a
PARAM b
CALL_ASSIGN res f
```

#### Instruction `return`

Sans valeur :
```
RETURN
```
Avec valeur :
```
RETURN_VAL  <valeur>
```

#### Structures de contrôle

**if / if-else**  
La condition est évaluée dans un temporaire, puis un saut conditionnel est émis vers le label `else` (ou `end`). Le bloc `then` est généré entre les deux labels.

```
<évaluation condition dans t0>
IFZ  Lelse  t0
  <bloc then>
  GOTO  Lend
Lelse:
  <bloc else>
Lend:
```

**while**

```
Ltest:
  <évaluation condition dans t0>
  IFZ  Lend  t0
  <corps>
  GOTO  Ltest
Lend:
```

**for**  
Le `for (init; cond; incr) corps` est réécrit comme un `while` :

```
<init>
Ltest:
  <évaluation condition dans t0>
  IFZ  Lend  t0
  <corps>
  <incr>
  GOTO  Ltest
Lend:
```

Les labels sont générés par `new_label()` pour garantir leur unicité.

## Analyseur lexical STRUCIT-backend (`lexeur_be.lex`)

Le lexeur backend est indépendant du lexeur frontend : il utilise l'option `prefix="backend"` de flex afin d'éviter les conflits de symboles (`backendlval`, `backendlineno`) lorsque les deux analyseurs coexistent dans le même binaire.

### Mots clés reconnus

Seuls les mots clés autorisés par STRUCIT-backend sont renvoyés comme tokens :
`extern`, `int`, `void`, `if`, `goto`, `return`.  
Les mots clés du frontend absents du backend (`for`, `while`, `else`, `struct`, `sizeof`) ne sont pas définis car tout identificateur inconnu sera reconnu comme `ID`.

### Tokens spécifiques au backend

Le lexeur reconnaît les mots clés propres au format de sortie produit par le générateur de code :
`FUNC`, `END_FUNC`, `DEC`, `PROTO`, `PARAM_TYPE`, `PARAM`, `CALL`.  
Ces tokens n'existent pas dans le frontend ; ils correspondent aux pseudo-instructions émises par `ecrire_quads_fichier`.

### Opérateurs

Les opérateurs arithmétiques et de comparaison sont reconnus à la fois sous leur forme symbolique (`+`, `-`, `<`, `==`, etc.) et sous leur forme mnémonique textuelle (`ADD`, `SUB`, `LT`, `EQ`, etc.) afin de couvrir les deux styles de sortie possibles du générateur.  
L'opérateur `->` est tokenisé (`ARROW`) bien qu'il ne soit pas utilisé dans la grammaire backend ; il est conservé pour robustesse lexicale.

### Identifiants et constantes

- Identifiants : `[a-zA-Z_][a-zA-Z0-9_]*` => token `ID`, valeur copiée avec `strdup`.
- Constantes entières : `[0-9]+` => token `CONST`, valeur convertie avec `atoi`.

### Gestion des espaces et des commentaires

Les espaces et tabulations sont silencieusement ignorés. Les commentaires `/* ... */` sont également ignorés via une règle regex complète. Les retours à la ligne renvoient le token `'\n'`, nécessaire à la grammaire backend pour délimiter certaines instructions.

### Erreurs lexicales

Tout caractère non reconnu produit un message d'erreur sur `stderr` avec le numéro de ligne et le caractère fautif, sans arrêter l'analyse.

## Analyseur syntaxique STRUCIT-backend (`structbe.y`)

### Principe général

Le parseur backend n'effectue aucune analyse sémantique : il vérifie uniquement que le code à trois adresses produit par le compilateur est lexicalement et syntaxiquement conforme au langage STRUCIT-backend. Sa grammaire est donc plus restrictive que celle du frontend, reflétant les contraintes propres au code à trois adresses.

### Principales différences avec la grammaire fournie

#### Contrainte trois adresses sur les expressions

La grammaire fournie autorisait des expressions arbitraires côté droit d'une affectation. La grammaire finale restreint chaque opérande d'un opérateur binaire à une `primary_expression` (identifiant ou constante), ce qui garantit qu'on ne peut écrire qu'une seule opération par instruction :

```
primary_expression '+' primary_expression = autorisé
(a + b) + c = refusé (imbrication interdite)
```

Cette contrainte est appliquée à `multiplicative_expression`, `additive_expression`, `relational_expression` et `equality_expression`.

#### Formes d'affectation limitées

La règle `expression` ne couvre que les affectations autorisées par le code trois adresses :
- `primary_expression '=' additive_expression` : affectation depuis une expression binaire ou simple (`x = y + z`, `x = y`)
- `unary_operator primary_expression '=' primary_expression` : affectation vers un pointeur déréférencé (`*p = y`) ou depuis une adresse

#### Labels et branchements

La grammaire fournie n'incluait pas les labels ni `goto`. Ils ont été ajoutés :

```yacc
labeled_statement : IDENTIFIER ':' statement ;
jump_statement : GOTO IDENTIFIER ';' ;
selection_statement : IF '(' equality_expression ')' GOTO IDENTIFIER ';' ;
```

Le branchement conditionnel est restreint à `if (cond) goto L;` sans bloc `else`, conformément à la spécification STRUCIT-backend.

#### Absence de `struct`, `sizeof`, boucles

Les règles `struct_specifier`, `sizeof`, `for`, `while`, `else` sont absentes : ces constructions n'ont pas d'équivalent direct en code trois adresses.

#### Arguments d'appel de fonction

Dans le backend, les arguments d'un appel de fonction sont des `primary_expression` uniquement (pas d'expressions arbitraires) :

```yacc
argument_expression_list : primary_expression
                         | argument_expression_list ',' primary_expression ;
```

## Difficultés rencontrées lors de la programmation

Claire : 
J'ai eu des difficultés à trouver l'architecture qui convenait le mieux pour la table des symboles. Au final j'ai opté pour la solution qui me parraissaient la plus simple à utiliser. La gestion des pointeurs de fonction tout au long des actions sémantiques a aussi été compliquée à faire. J'ai du réfléchir à comment prendre en compte des états différents des expressions en fonction de si un pointeur de fonction été impliqué ou non par exemple. La solution a été d'utiliser des attributs state qui fonctionnent comme des flags pour différencier les cas possibles. Egalement les erreurs de segmentation fault durant le débuggage des actions sémantiques m'ont pris beaucoup de temps et m'ont confronter à la difficulté de la gestion mémoire en C. Particulièrement sur la question de la propriété des données en mémoire.

Maelle :
La principale difficulté a été d'obtenir une grammaire sans conflits shift/reduce ni reduce/reduce. La grammaire initiale, écrite après le développement du frontend et du générateur de code, présentait plusieurs conflits dus à l'ambiguïté entre `unary_expression` utilisé comme opérande et comme instruction complète, et à la règle `expression` trop générale héritée du frontend.
Un second obstacle a été le parseur backend développé après la génération de code, ce qui a impliqué de bien comprendre la structure exacte du fichier produit par `ecrire_quads_fichier` pour s'assurer que la grammaire acceptait précisément ce format. Quelques ajustements ont été nécessaires lorsqu'il s'est avéré que certains cas de génération (ex. appels sans valeur de retour, déclarations `extern`) produisaient des formes que la première version de la grammaire ne couvrait pas.

## Fonctionnement final du compilateur

Claire :
Lorsqu'une erreur est appelée par une fonction annexe (par exemple dans le cadre de check_struct_field_access) elle fait un exit(1) mais cela ferme le fichier bison avec une erreur donc au final l'erreur s'affichant sur le terminal est yyerror. Donc le message qui convient ne s'affiche pas correctement. En dehors de cela, l'analyse lexicale par le fichier lex, la table des symboles, le système de typage et la gestion des analyses sémantiques fonctionnent correctement. 

Maelle : 
Le générateur de code (gencode.c) produit un fichier STRUCIT-backend syntaxiquement correct pour tout programme Frontend valide. Les quads sont émis progressivement lors de l'analyse syntaxique via emettre_quad, puis sérialisés par ecrire_quads_fichier. Le parseur backend (structbe.y + lexeur_be.lex) valide ensuite ce fichier sans erreur, confirmant ainsi la conformité du code généré. Cette chaîne fonctionne de bout en bout pour tous les cas couverts par le Frontend (déclarations, fonctions, expressions arithmétiques/logiques, structures de contrôle, appels de fonction, accès aux champs de structure).

## Conclusion

Claire : 
Lors de ce programme j'ai pu énormément apprendre sur le fonctionnement d'un compilateur. Faire le projet en parallèle des cours m'a aidé à mieux les comprendre. J'ai trouvé le projet long et difficile mais c'est très gratifiant lorsqu'au final le programme réussit. Au final j'ai aussi beaucoup appris sur les règles de fonctionnement du langage C. En effet les langaages STRUCIT-Frontend et STRUCIT-Backend étant des sous-langages du C, pour savoir si tel opérateur était valide avec tel type j'ai du passer beaucoup de temps sur le fonctionnement du C. 

Maëlle : 
Ce projet m’a permis d’approfondir ma compréhension des compilateurs. J’ai appris à gérer les conflits dans une grammaire (shift/reduce, reduce/reduce) et à concevoir un générateur de code à trois adresses structuré. La réalisation du parseur backend après le générateur de code m’a obligée à bien documenter le format de sortie attendu. J’ai également pris conscience de l’importance d’une communication efficace au sein du binôme, car nos parties devaient être cohérentes.