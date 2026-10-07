# Sujet 13 — Module d'authentification et de gestion des droits d'accès aux tableaux de bord

Projet du cours **Langages et Environnements Évolués (LEE)** — Master 1 ID.
Livrable : application fonctionnelle (interface web en français + API) + code source + tests + documentation + Docker + CI/CD.

## 1. Démarrage rapide

**Le plus simple (Windows) : double-cliquer sur `lancer.bat`.** Il installe les dépendances la première fois, démarre le serveur,
ouvre le navigateur sur http://localhost:8000 et conserve les données dans `auth.db`. Fermer la fenêtre noire arrête l'application.

**Windows (PowerShell, ouvert dans le dossier `projet13`)**

```powershell
python -m pip install --user -r requirements.txt
$env:AUTH_SECRET_KEY = "une-longue-phrase-secrete-de-plus-de-32-caracteres"
$env:AUTH_DB_PATH = "auth.db"            # facultatif : sans cette ligne, les données sont en mémoire
python -m uvicorn app.main:app --reload
```

Ouvrir ensuite **http://localhost:8000** : c'est l'application.
La documentation technique de l'API (en français) est sur **http://localhost:8000/docs**.

> Réseau d'école ou d'entreprise avec erreur `CERTIFICATE_VERIFY_FAILED` : ajouter
> `--trusted-host pypi.org --trusted-host files.pythonhosted.org` à la commande `pip`.

**Linux / macOS**

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export AUTH_SECRET_KEY="$(python -c 'import secrets; print(secrets.token_urlsafe(48))')"
export AUTH_DB_PATH=./auth.db
uvicorn app.main:app --reload
```

**Docker**

```bash
docker build -t auth-dashboard .
docker run -p 8000:8000 -e AUTH_SECRET_KEY=une-longue-phrase-secrete-de-plus-de-32-caracteres -v auth-data:/data auth-dashboard
```

**Tests** : `python -m pytest --cov=app` (149 tests, ~99 % de couverture) · **Lint** : `ruff check .`

## 2. Utiliser l'application

1. **Créer un compte** (onglet « Créer un compte ») et **choisir son rôle** : *Administrateur*, *Analyste* ou *Utilisateur*.
   Vous êtes connecté automatiquement.
2. **Toutes les fonctionnalités sont visibles pour tous les rôles** : Tableaux de bord, Partage, Administration,
   Journal d'audit, Droits par rôle.
3. Si vous essayez une action qui dépasse votre rôle, l'application affiche un **message d'accès refusé** en français,
   qui nomme votre rôle, l'action et les rôles autorisés. Chaque résultat (réussi ✔ ou refusé ✖) est aussi listé dans
   le panneau « Résultat de vos actions ».

### Scénario de démonstration (5 minutes)

| Étape | Qui | Action | Résultat attendu |
|---|---|---|---|
| 1 | `admin1` (Administrateur) | Créer le tableau « Ventes 2026 » | ✔ créé |
| 2 | `ana` (Analyste) | Créer le tableau « Marges » | ✔ créé (elle en est propriétaire) |
| 3 | `ana` | Onglet *Administration* → « Appliquer » sur un compte | ✖ refusé : seul l'administrateur gère les rôles |
| 4 | `ana` | Supprimer un tableau | ✖ refusé : seul l'administrateur supprime |
| 5 | `uti` (Utilisateur) | Liste des tableaux | vide : rien n'est partagé avec lui |
| 6 | `uti` | Créer un tableau · Partager · Journal d'audit | ✖ ✖ ✖ trois refus explicites |
| 7 | `admin1` | *Partage* : « Ventes 2026 » avec `uti` en lecture seule | ✔ partagé |
| 8 | `uti` | Le tableau apparaît (accès « lecture »), cliquer sur *Modifier* | ✖ refusé |
| 9 | `admin1` | *Journal d'audit* | toutes les actions et tous les refus, datés |

Captures d'écran de ce parcours : dossier `docs/captures/`.
Le script `scripts/parcours_navigateur.py` rejoue ce scénario automatiquement dans Chromium (voir en-tête du script).

## 3. Choix technologique (justification — compétence n°1 du cours)

| Besoin | Choix | Pourquoi (référence cours) |
|---|---|---|
| API HTTP | **Python / FastAPI** | Validation automatique Pydantic, typage annoté, doc OpenAPI générée (Ch. 5, §5.7–5.8) |
| Interface | Une page HTML/JavaScript sans dépendance externe, servie par l'application | Fonctionne hors ligne et sur réseau filtré ; le navigateur suffit |
| Domaine | dataclasses + `Enum` typés | Typage fort, contrats explicites (Ch. 2) |
| Dépôt de données | `Protocol` + **SQLite** (persistant) ou mémoire | Programmer contre une interface, inversion de dépendance (Ch. 2 §2.9, Ch. 6 §6.5.1) |
| État partagé | `RLock` dans le dépôt | Protection des sections critiques (Ch. 4 §4.5) |
| Tests | pytest, fixtures, paramétrage, horloge simulée | Pyramide des tests, doublures (Ch. 9 §9.3) |
| Industrialisation | Docker multi-étapes + GitHub Actions | Ch. 6 §6.9, Ch. 9 §9.6–9.7 |

## 4. Architecture en couches

```
Navigateur ─► app/static/index.html   interface en français (appelle l'API en JSON)
HTTP  ──►  app/main.py        routes FastAPI (couche mince : erreurs métier → codes HTTP + messages français)
              │
              ▼
          app/service.py      AuthService : logique métier (aucune dépendance HTTP)
           │        │
           ▼        ▼
   app/rbac.py   app/security.py     règles d'accès + libellés français / bcrypt + JWT purs
           │
           ▼
   app/repository.py   Protocol Repository + InMemoryRepository + make_repository()
   app/sqlite_repository.py   SQLiteRepository (requêtes paramétrées, FK, WAL)
   app/models.py       entités, rôles, permissions, schémas Pydantic
```

## 5. Modèle de droits

**Rôles → permissions (RBAC)**

| Fonctionnalité | Administrateur | Analyste | Utilisateur |
|---|:-:|:-:|:-:|
| Consulter un tableau de bord (partagé avec lui) | ✔ | ✔ | ✔ |
| Créer ou modifier un tableau de bord | ✔ | ✔ | |
| Supprimer un tableau de bord | ✔ | | |
| Partager un tableau de bord | ✔ | ✔ | |
| Gérer les rôles des utilisateurs | ✔ | | |
| Consulter le journal d'audit | ✔ | | |

**ACL par tableau de bord** — le rôle seul ne suffit pas. Décision (voir `rbac.can_access` et `service._authorized_dashboard`),
dans cet ordre :
1. le **rôle** possède la permission, sinon **403** « Accès refusé… » (avant même de chercher le tableau) ;
2. le tableau est **visible** (administrateur, propriétaire ou partagé avec l'utilisateur), sinon **404** « introuvable ou non partagé avec vous » ;
3. le **niveau d'accès** sur ce tableau suffit (lecture seule ou écriture), sinon **403** « lecture seule ».

**Création de compte** : le rôle est choisi par l'utilisateur (demande du sujet, mode démonstration).
Avec `AUTH_ALLOW_ROLE_CHOICE=0`, le rôle demandé est ignoré : le premier compte devient administrateur, les suivants
sont des utilisateurs, et seul un administrateur peut changer un rôle.

## 6. Mesures de sécurité implémentées

- Mots de passe hachés avec **bcrypt** (sel + coût 12), jamais stockés en clair ; politique : 8+ car., maj., min., chiffre.
- **JWT** signés HS256 : algorithme **fixé côté serveur** (rejet de `alg: none`), claims `exp`/`iat`/`jti`/`type`.
- Deux jetons : *access* (15 min) et *refresh* (7 j) ; **rotation** du refresh (usage unique) ; **déconnexion** = révocation par `jti`.
  L'interface renouvelle la session automatiquement.
- Le rôle est **relu en base** à chaque requête : une rétrogradation est immédiate, un jeton ne peut pas escalader les privilèges.
- **Verrouillage** du compte 15 min après 5 échecs ; message d'erreur identique pour « utilisateur inconnu » et
  « mauvais mot de passe » + hash factice (anti-énumération de comptes, y compris par temps de réponse).
- Une ressource non partagée répond **404** (son existence n'est pas révélée) ; **403** si le rôle ou le niveau d'accès manque.
- **Journal d'audit** (connexions, échecs, refus, changements de rôle, partages), consultable par l'administrateur.
- Un administrateur ne peut pas se rétrograder lui-même (évite de se retrouver sans administrateur).
- Interface : tout texte affiché passe par `textContent` (aucune injection HTML/XSS possible).
- Secret JWT lu dans `AUTH_SECRET_KEY` ; conteneur exécuté sans root.

## 7. Routes de l'API

| Méthode | Route | Droit requis |
|---|---|---|
| GET | `/` | page de l'application |
| GET | `/roles` | public (rôles et droits) |
| POST | `/auth/register`, `/auth/login`, `/auth/refresh` | public |
| POST | `/auth/logout` | jeton valide |
| GET | `/users/me`, `/users` | jeton valide (annuaire sans donnée sensible) |
| PATCH | `/users/{id}/role` | `user:manage` (administrateur) |
| GET/POST | `/dashboards` | lecture (filtrée) / `dashboard:write` |
| GET/PUT/DELETE | `/dashboards/{id}` | read / write / delete + niveau d'accès |
| GET/POST/DELETE | `/dashboards/{id}/grants[/{user_id}]` | lecture / `access:grant` + écriture sur le tableau |
| GET | `/audit` | `audit:read` (administrateur) |

## 8. Stratégie de tests (pyramide, Ch. 9)

| Niveau | Fichier | Contenu |
|---|---|---|
| Unitaires purs | `test_security.py`, `test_rbac.py` | hachage, politique, JWT (expiré, falsifié, `alg:none`, mauvais type), matrice rôles × permissions paramétrée |
| Service (sans HTTP) | `test_service.py` | verrouillage avec **horloge simulée** (fake), rotation refresh, révocation, anti-énumération, audit |
| Contrat des dépôts | `conftest.py` | **toute** la suite service + API est exécutée sur le dépôt mémoire ET SQLite |
| Persistance | `test_sqlite.py` | redémarrage sur fichier réel, injection SQL, unicité, cascade, choix du dépôt |
| Intégration HTTP | `test_api.py` | codes 401/403/404/409/422, cycle complet de partage, escalade de privilèges, accès admin |
| Application | `test_interface.py` | choix du rôle, messages d'erreur français pour chaque fonction réservée, annuaire, accès « lecture/écriture », page web |
| Bout en bout | `scripts/parcours_navigateur.py` | scénario complet des 3 rôles dans un vrai navigateur (non exécuté en CI) |

## 9. CI/CD

`.github/workflows/ci.yml` : **lint (ruff) → tests en matrice Python 3.11/3.12/3.13 avec seuil de couverture 90 % → build Docker**,
chaque job bloquant le suivant (`needs`).

## 10. Limites et pistes d'amélioration (à mentionner à l'oral)

- **Rôle choisi librement à l'inscription** : voulu pour la démonstration. En production, désactiver (`AUTH_ALLOW_ROLE_CHOICE=0`)
  et faire attribuer les rôles par un administrateur.
- SQLite convient à une instance unique ; pour plusieurs instances, implémenter `Repository` avec PostgreSQL (le service ne change pas).
  Sans `AUTH_DB_PATH`, le dépôt est en mémoire (volatile).
- Pas de limitation de débit par IP (seul le verrouillage par compte existe) ; pas de 2FA ; HS256 → RS256 si plusieurs services valident les jetons.
- Table `revoked_tokens` jamais purgée (à nettoyer à l'expiration des jetons, ou Redis avec TTL).
- Les tableaux de bord portent un nom et une description : le contenu analytique (graphiques, indicateurs) est hors du périmètre
  du sujet, qui porte sur l'authentification et les droits d'accès.
