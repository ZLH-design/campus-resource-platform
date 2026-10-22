@echo off
REM campus-resource-platform 目录骨架创建脚本（Windows）
REM 用法：双击运行，或在仓库父目录执行 create-structure.bat

set ROOT=campus-resource-platform

if not exist "%ROOT%" mkdir "%ROOT%"
cd "%ROOT%"

mkdir frontend 2>nul

for %%s in (m1 m2 m3 d) do (
    mkdir "services\%%s-service\src\main\java" 2>nul
    mkdir "services\%%s-service\src\main\resources\db\migration" 2>nul
    mkdir "services\%%s-service\src\test\java" 2>nul
)

mkdir openapi 2>nul
mkdir deploy\nginx 2>nul
mkdir deploy\initdb 2>nul
mkdir docs\requirements 2>nul
mkdir docs\adr 2>nul
mkdir docs\ai 2>nul
mkdir docs\risks 2>nul
mkdir .github\workflows 2>nul

REM Git 不跟踪空目录，逐个放 .gitkeep
for /f "delims=" %%d in ('dir /ad /b /s') do (
    if not exist "%%d\.gitkeep" type nul > "%%d\.gitkeep"
)

echo.
echo 目录骨架创建完成，结构如下：
tree /a /f . | more
cd ..
