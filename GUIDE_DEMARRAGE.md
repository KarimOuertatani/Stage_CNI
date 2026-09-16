# 🚀 Démarrage — Backend FitForge

## La méthode simple : double-cliquer sur `run.bat`

Dans le dossier `api/`, **double-clique sur le fichier `run.bat`**.
Il fait tout automatiquement :
1. démarre la base de données (Docker) ;
2. démarre le serveur.

C'est prêt quand la fenêtre affiche :
```
Started ApiApplication
```

Puis ouvre dans ton navigateur : **http://localhost:8081/swagger-ui.html**

Pour **arrêter** le serveur : clique dans la fenêtre noire et fais `Ctrl + C`.

> ℹ️ On utilise le port **8081** (et non 8080) car le 8080 est occupé par
> Docker Desktop sur cette machine. C'est déjà réglé dans `run.bat`.

---

## Tester l'API dans Swagger

1. Ouvre **http://localhost:8081/swagger-ui.html**
2. Bloc **Authentification** → `POST /api/v1/auth/register` → **Try it out** :
   ```json
   { "email": "sami@fitforge.tn", "password": "MotDePasse123", "fullName": "Sami" }
   ```
   → **Execute**, puis copie le `token` dans la réponse.
3. Clique **Authorize** (🔒 en haut à droite), colle le token, valide.
4. Tu peux maintenant tester tous les autres endpoints.

---

## Consulter la base de données

Ouvre une console SQL dans la base :
```bash
docker exec -it fitforge-db psql -U fitforge -d fitforge
```
Commandes utiles une fois dedans :
```sql
\dt                        -- lister les tables
SELECT * FROM users;       -- voir les comptes
SELECT name FROM exercises;-- voir les exercices
\q                         -- quitter
```

> Avec un outil graphique (DBeaver / pgAdmin) : host `localhost`, port `5432`,
> base / utilisateur / mot de passe = `fitforge`.

---

## Si `run.bat` ne marche pas

- **La fenêtre se ferme tout de suite** → ouvre-la depuis un terminal pour voir
  l'erreur : dans le dossier `api/`, tape `run.bat` (ou `.\run.bat` en PowerShell).
- **« Docker … »** ou base injoignable → ouvre **Docker Desktop** et attends
  qu'il soit démarré, puis relance `run.bat`.
- **Erreur de version Java** → vérifie que Java 21 est bien là :
  `C:\Users\karim\.jdks\ms-21.0.8`. Le chemin est écrit dans `run.bat`.

---

## Alternative sans `run.bat` (en 2 commandes)

Base :
```bash
docker compose up -d
```
Serveur (Git Bash) :
```bash
JAVA_HOME="C:/Users/karim/.jdks/ms-21.0.8" ./mvnw spring-boot:run -Dspring-boot.run.arguments="--server.port=8081"
```
> ⚠️ Cette commande est en syntaxe **Bash** : elle ne marche **pas** dans
> PowerShell / l'invite Windows. Pour ces terminaux, utilise plutôt `run.bat`