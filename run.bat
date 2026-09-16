@echo off
setlocal
cd /d "%~dp0"

REM ============================================================
REM   FitForge - lanceur tout-en-un (double-cliquer ce fichier)
REM ============================================================

REM --- Java 21 (obligatoire : le "java" par defaut est en Java 17) ---
set "JAVA_HOME=C:\Users\karim\.jdks\ms-21.0.8"

REM --- Maven deja telecharge en cache (on evite le wrapper qui
REM     replante au telechargement). Si le cache a change, on
REM     retombe sur le wrapper mvnw.cmd. ---
set "MVN=C:\Users\karim\.m2\wrapper\dists\apache-maven-3.9.16\56ba1f9f\bin\mvn.cmd"
if not exist "%MVN%" set "MVN=%~dp0mvnw.cmd"

echo ============================================================
echo   FitForge - demarrage
echo ============================================================
echo.

echo [1/2] Demarrage de la base de donnees (Docker)...
docker compose up -d --wait
if errorlevel 1 (
  echo.
  echo ERREUR: la base n'a pas demarre.
  echo         Verifie que Docker Desktop est ouvert, puis relance ce fichier.
  echo.
  pause
  exit /b 1
)

echo.
REM  On lance sur le port 8081 car le 8080 est occupe par Docker Desktop
REM  (wslrelay) sur cette machine. Si un jour le 8080 est libre, tu peux
REM  remplacer 8081 par 8080 ci-dessous.
echo [2/2] Demarrage du serveur (port 8081)...
echo       - Attends la ligne : Started ApiApplication
echo       - Swagger : http://localhost:8081/swagger-ui.html
echo       - Pour arreter : Ctrl + C
echo.
call "%MVN%" spring-boot:run -Dspring-boot.run.arguments="--server.port=8081"

echo.
echo Serveur arrete.
pause
