@echo on
setlocal

set "SOURCE_ROOT=%SRC_DIR%\source"
set "BUILD_TREE=%SRC_DIR%\build"
set "APYCULA_SITE=%SRC_DIR%\apycula-site"
set "PYTHONNOUSERSITE=1"

"%PYTHON%" -m pip install --no-deps --no-index ^
  --target "%APYCULA_SITE%" ^
  "%SRC_DIR%\apycula-0.32-py3-none-any.whl"
if errorlevel 1 exit /b 1

set "PYTHONPATH=%APYCULA_SITE%"
"%PYTHON%" -c "from apycula import chipdb; assert callable(chipdb.load_chipdb)"
if errorlevel 1 exit /b 1

"%PYTHON%" "%SOURCE_ROOT%\tools\prepare_ice40.py"
if errorlevel 1 exit /b 1
"%PYTHON%" "%SOURCE_ROOT%\tools\prepare_apicula.py"
if errorlevel 1 exit /b 1
"%PYTHON%" "%SOURCE_ROOT%\tools\prepare_xilinx.py"
if errorlevel 1 exit /b 1

if not defined SCCACHE_DIR set "SCCACHE_DIR=%SRC_DIR%\sccache-cache"
if not defined SCCACHE_CACHE_SIZE set "SCCACHE_CACHE_SIZE=1G"
set "SCCACHE_BASEDIRS=%SRC_DIR%"
set "SCCACHE_CONF=%SRC_DIR%\sccache-config.toml"
type nul > "%SCCACHE_CONF%"

cmake -S "%SOURCE_ROOT%" -B "%BUILD_TREE%" -G Ninja ^
  "-DARCH=ice40;himbaechel" ^
  "-DICE40_DEVICES=384" ^
  "-DICEBOX_DATADIR=%SOURCE_ROOT%\deps\icebox" ^
  "-DHIMBAECHEL_UARCH=gowin;xilinx" ^
  "-DHIMBAECHEL_GOWIN_DEVICES=GW1N-1" ^
  "-DHIMBAECHEL_XILINX_DEVICES=xc7a100t" ^
  "-DHIMBAECHEL_PRJXRAY_DB=%SOURCE_ROOT%\deps\prjxray-db" ^
  "-DXilinxChipdb_Python3_EXECUTABLE=%PYTHON%" ^
  -DBUILD_GUI=ON ^
  -DBUILD_PYTHON=ON ^
  -DBUILD_RUST=OFF ^
  -DBUILD_TESTS=OFF ^
  -DUSE_IPO=OFF ^
  -DCMAKE_BUILD_TYPE=Release ^
  "-DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX%" ^
  "-DCMAKE_PREFIX_PATH=%LIBRARY_PREFIX%" ^
  "-DCMAKE_CXX_COMPILER_LAUNCHER=sccache" ^
  "-DPython3_EXECUTABLE=%PYTHON%" ^
  "-DCURRENT_GIT_VERSION=%PKG_VERSION%"
if errorlevel 1 exit /b 1

sccache --start-server
if errorlevel 1 exit /b 1
sccache --zero-stats
if errorlevel 1 exit /b 1
cmake --build "%BUILD_TREE%" --parallel --target nextpnr-ice40 nextpnr-himbaechel
set "BUILD_STATUS=%ERRORLEVEL%"
sccache --show-stats
sccache --stop-server
if errorlevel 1 exit /b 1
if not "%BUILD_STATUS%"=="0" exit /b %BUILD_STATUS%

cmake --install "%BUILD_TREE%"
if errorlevel 1 exit /b 1
