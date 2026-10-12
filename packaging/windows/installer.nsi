; KD Mail – Windows-installationsprogram (NSIS)
; Bygges af scripts/package-windows.sh:
;   makensis -DVERSION=x -DSRCDIR=<core> -DOUTFILE=<exe> -DICON=<ico> installer.nsi
Unicode true
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!include "FileFunc.nsh"

!define APPNAME "KD Mail"
!define PUBLISHER "Kristendemokraterne"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\KDMail"

Name "${APPNAME}"
OutFile "${OUTFILE}"
; Installeres pr. bruger – kræver ikke administratorrettigheder
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\KD Mail"
InstallDirRegKey HKCU "Software\KDMail" "InstallDir"
BrandingText "${APPNAME} ${VERSION}"
VIProductVersion "1.0.0.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "FileDescription" "${APPNAME} installation"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "KD Mail er baseret på Mozilla Thunderbird (MPL 2.0)"

!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\thunderbird.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Start KD Mail nu"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Danish"

Section "KD Mail" SecMain
  SetOutPath "$INSTDIR"
  ; Fjern gamle filer ved opdatering, men behold intet brugerdata (det ligger i %APPDATA%\KDMail)
  RMDir /r "$INSTDIR\distribution"
  File /r "${SRCDIR}\*.*"
  File "/oname=kd-mail.ico" "${ICON}"

  CreateShortcut "$SMPROGRAMS\KD Mail.lnk" "$INSTDIR\thunderbird.exe" "" "$INSTDIR\kd-mail.ico" 0
  CreateShortcut "$DESKTOP\KD Mail.lnk" "$INSTDIR\thunderbird.exe" "" "$INSTDIR\kd-mail.ico" 0

  WriteUninstaller "$INSTDIR\Afinstaller KD Mail.exe"
  WriteRegStr HKCU "Software\KDMail" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTKEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\kd-mail.ico"
  WriteRegStr HKCU "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Afinstaller KD Mail.exe"'
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "${UNINSTKEY}" "EstimatedSize" $0
SectionEnd

Section "Uninstall"
  Delete "$SMPROGRAMS\KD Mail.lnk"
  Delete "$DESKTOP\KD Mail.lnk"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTKEY}"
  DeleteRegKey HKCU "Software\KDMail"
SectionEnd
