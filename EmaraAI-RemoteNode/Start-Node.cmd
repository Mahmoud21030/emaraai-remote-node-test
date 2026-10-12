@echo off
title EmaraAI remote node
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Node.ps1" %*
