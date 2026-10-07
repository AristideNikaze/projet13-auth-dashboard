@echo off
setlocal
cd /d "%~dp0"
title Tableaux de bord - serveur (fermer cette fenetre pour arreter)

rem --- Reglages : vous pouvez changer la phrase secrete (32 caracteres minimum) ---
set AUTH_SECRET_KEY=une-longue-phrase-secrete-de-plus-de-32-caracteres
set AUTH_DB_PATH=%~dp0auth.db
set AUTH_ALLOW_ROLE_CHOICE=1

python --version >nul 2>&1
if errorlevel 1 (
  echo Python est introuvable. Installez Python 3.10 ou plus recent depuis python.org
  echo en cochant "Add Python to PATH", puis relancez ce fichier.
  pause
  exit /b 1
)

python -c "import fastapi, uvicorn, jwt, bcrypt" >nul 2>&1
if errorlevel 1 (
  echo Installation des dependances, une seule fois...
  python -m pip install --user --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt
  if errorlevel 1 (
    echo.
    echo L'installation a echoue. Verifiez votre connexion internet puis relancez ce fichier.
    pause
    exit /b 1
  )
)

echo.
echo Application disponible sur http://localhost:8000
echo Vos donnees sont conservees dans le fichier auth.db
echo Fermez cette fenetre pour arreter le serveur.
echo.
start "" cmd /c "timeout /t 3 >nul & start http://localhost:8000"
python -m uvicorn app.main:app --port 8000
pause
