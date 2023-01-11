program NativeBridgeFileGeneratorHelper;

{$APPTYPE CONSOLE}

{$R *.res}

{$I ..\..\..\..\Source\Alcinoe.inc}

uses
  Winapi.Windows,
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  system.AnsiStrings,
  system.Math,
  ALJsonDoc,
  ALFiles,
  ALString,
  ALExecute,
  ALCommon,
  ALXmlDoc,
  ALStringList;


{******************************************************************************************************}
function MergeInterfaceSrc(const AMasterSrc: AnsiString; const aCompareWithSrc: AnsiString): AnsiString;

  {~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
  Procedure _InitSignatures(const aSrc: AnsiString; const aSignatures: TALStringList);
  begin
    var LSrcLst := TAlStringList.Create;
    try
      LSrcLst.Text := aSrc;
      for var I := 0 to LSrcLst.Count - 1 do begin
        var LSrcLine := ALTrim(LSrcLst[i]);
        var LSignature: ansiString := '';
        var LPropertyPos := ALposExIgnoreCase('property',LSrcLine); // {class} property GET: JHttpMethod read _GetGET;
        var LfunctionPos := ALposExIgnoreCase('function',LSrcLine); // {class} function _GetINSTANCE: JCallbackManager_Factory; cdecl;
        var LProcedurePos := ALposExIgnoreCase('procedure',LSrcLine); // procedure logInWithReadPermissions(fragment: Jfragment_app_Fragment; collection: JCollection); cdecl; overload;
        var LinterfacePos := ALposExIgnoreCase(' = interface(',LSrcLine); // FBSDKGraphRequest = interface(NSObject)
        var LGUIDPos := ALposExIgnoreCase('[''{',LSrcLine); // ['{C964E2C1-1500-4A35-B61D-02F46AF53B3C}']
        var LMethodNamePos := ALposExIgnoreCase('[MethodName(''',LSrcLine); // [MethodName('initWithGraphPath:HTTPMethod:')]
        var LENDPos := ALposExIgnoreCase('end;',LSrcLine); // end;
        if (LfunctionPos > 0) or (LProcedurePos > 0) or (LPropertyPos > 0) then begin
          if (LfunctionPos <= 0) then LfunctionPos := Maxint;
          if (LProcedurePos <= 0) then LProcedurePos := Maxint;
          if (LPropertyPos <= 0) then LPropertyPos := Maxint;
          if LfunctionPos = minIntValue([LfunctionPos, LProcedurePos, LPropertyPos]) then begin
            LProcedurePos := -1;
            LPropertyPos := -1;
          end
          else if LProcedurePos = minIntValue([LfunctionPos, LProcedurePos, LPropertyPos]) then begin
            LfunctionPos := -1;
            LPropertyPos := -1;
          end
          else if LPropertyPos = minIntValue([LfunctionPos, LProcedurePos, LPropertyPos]) then begin
            LfunctionPos := -1;
            LProcedurePos := -1;
          end;
          if ((LfunctionPos > 0) or (LProcedurePos > 0)) and (alpos('; cdecl;', LSrcLine) <= 0) then raise Exception.Create('Error BD102BA5-D235-4A00-A3F4-612C8EE6DD71');
          var LOpenBracketPos := ALpos('(', LSrcLine);
          var LCloseBracketPos := ALpos(')', LSrcLine);
          var LColonPos := ALpos(':', LSrcLine, max(LCloseBracketPos, 1));
          var LSemiColonPos := ALpos(';', LSrcLine, max(LColonPos,1));
          if LSemiColonPos <= 0 then raise Exception.Create('Error 22AD5097-FF70-47E5-B3E4-4B78BBE0FF08');
          var LNamePos: integer;
          if LfunctionPos > 0 then begin
            LSignature := 'function';
            LNamePos := LfunctionPos + length('function');
          end
          else if LPropertyPos > 0 then begin
            LSignature := 'property';
            LNamePos := LPropertyPos + length('property');
          end
          else if LProcedurePos > 0 then begin
            LSignature := 'procedure';
            LNamePos := LProcedurePos + length('procedure');
          end
          else raise Exception.Create('Error 6E2AB0AD-0D6D-49BE-A3F6-A98DDFD91685');
          if LOpenBracketPos {(} > 0 then begin
            LSignature := LSignature + ':' + ALTrim(ALcopyStr(LSrcLine,LNamePos,LOpenBracketPos-LNamePos)) + '~'; // procedure:logInWithReadPermissions~
            if LCloseBracketPos < LOpenBracketPos then raise Exception.Create('Error B8EBF18A-2AFC-4CF3-8FBE-3AF250A2B08A');
            var LParamsSrc := ALCopyStr(LSrcLine, LOpenBracketPos+1, LCloseBracketPos-LOpenBracketPos-1); // fragment: Jfragment_app_Fragment; collection: JCollection
            var LParamsLst := TAlStringList.Create;
            try
              LParamsLst.NameValueSeparator := ':';
              LParamsLst.LineBreak := ';';
              LParamsLst.Text := LParamsSrc;
              for var J := 0 to LParamsLst.Count - 1 do
                LSignature := LSignature + '|' + ALTrim(LParamsLst.ValueFromIndex[J]); // procedure:logInWithReadPermissions~|Jfragment_app_Fragment|JCollection
            finally
              ALFreeAndNil(LParamsLst);
            end;
          end
          else if LColonPos {:} > 0 then begin
            LSignature := LSignature + ':' + ALTrim(ALcopyStr(LSrcLine,LNamePos,LColonPos-LNamePos)) + '~'; // function:_GetINSTANCE~
          end
          else if LSemiColonPos {;} > 0 then begin
            LSignature := LSignature + ':' + ALTrim(ALcopyStr(LSrcLine,LNamePos,LSemiColonPos-LNamePos) + '~'); // procedure:delete~
          end
          else raise Exception.Create('Error 6CD487C1-088B-459B-BC0F-C3354A83428E');
          //----
          if LColonPos > 0 then begin
            LSignature := LSignature + '=' + ALTrim(ALcopyStr(LSrcLine,LColonPos+1,LSemiColonPos-LColonPos-1)); // function:_GetINSTANCE~=JCallbackManager_Factory
          end;
          aSignatures.Add(LSignature + '@' + LSrcLine); // function:_GetINSTANCE~=JCallbackManager_Factory@{class} function _GetINSTANCE: JCallbackManager_Factory; cdecl;
        end
        else if (LinterfacePos > 0) then begin
          LSignature := 'interface:' + ALTrim(ALcopyStr(LSrcLine,1,LinterfacePos)) + '~'; // interface:FBSDKGraphRequest~
          var LOpenBracketPos := ALpos('(', LSrcLine);
          if LOpenBracketPos < 0 then raise Exception.Create('Error 9CABF6BA-9A40-46F4-A00E-D1E7B637B5E2');
          var LCloseBracketPos := ALpos(')', LSrcLine);
          if LCloseBracketPos < LOpenBracketPos then raise Exception.Create('Error 370F8029-6BDB-4CE4-A009-52492A6B097A');
          LSignature := LSignature + '=' + ALCopyStr(LSrcLine, LOpenBracketPos+1, LCloseBracketPos-LOpenBracketPos-1); // interface:FBSDKGraphRequest~=NSObject
          aSignatures.Add(LSignature + '@' + LSrcLine);
        end
        else if (LGUIDPos > 0) then begin
          LSignature := 'GUID~' + ALTrim(LSrcLine); // GUID~['{C964E2C1-1500-4A35-B61D-02F46AF53B3C}']
          aSignatures.Add(LSignature + '@' + LSrcLine);
        end
        else if (LMethodNamePos > 0) then begin
          LSignature := ALTrim(LSrcLine) + '~'; // [MethodName('initWithGraphPath:HTTPMethod:')]~
          aSignatures.Add(LSignature + '@' + LSrcLine);
        end
        else if (LENDPos > 0) then begin
          LSignature := ALTrim(LSrcLine) + '~'; // end;~
          aSignatures.Add(LSignature + '@' + LSrcLine);
        end
        else raise Exception.Create('Error 4D8A11C5-E5C3-458A-B7ED-ACF188267530');
      end;
    finally
      ALfreeAndNil(LSrcLst);
    end;
  end;

begin
  var LMasterSignatures := TALStringList.Create;
  var LCompareWithSignatures := TALStringList.Create;
  try
    _InitSignatures(AMasterSrc, LMasterSignatures);
    _InitSignatures(aCompareWithSrc, LCompareWithSignatures);
    Result := '';
    for var I := 0 to LMasterSignatures.Count - 1 do begin
      LMasterSignatures.NameValueSeparator := '@';
      LCompareWithSignatures.NameValueSeparator := '@';
      var LSignature := LMasterSignatures.Names[i]; // function:_GetINSTANCE~|Jfragment_app_Fragment|JCollection=JCallbackManager_Factory
      if (LSignature = '') then raise Exception.Create('Error 91188D20-B1C6-4C63-A603-0B97149CA132');
      if (LCompareWithSignatures.IndexOfName(LSignature) >= 0) then begin
        result := result + #13#10 + '  ' + LMasterSignatures.ValueFromIndex[i] // {class} function _GetINSTANCE: JCallbackManager_Factory; cdecl;
      end
      else begin
        LMasterSignatures.NameValueSeparator := '~';
        LCompareWithSignatures.NameValueSeparator := '~';
        LSignature := LMasterSignatures.Names[i]; // function:_GetINSTANCE
        if LSignature='GUID' then begin
          LMasterSignatures.NameValueSeparator := '@';
          LCompareWithSignatures.NameValueSeparator := '@';
          result := result + #13#10 + '  ' + LMasterSignatures.ValueFromIndex[i] // ['{1233C916-F3DA-45F0-8F05-F702A42C2BBE}']
        end
        else begin
          var J := LCompareWithSignatures.IndexOfName(LSignature);
          if (J >= 0) then begin
            LMasterSignatures.NameValueSeparator := '@';
            LCompareWithSignatures.NameValueSeparator := '@';
            result := result + #13#10 + '  ' + LCompareWithSignatures.ValueFromIndex[J];
          end;
        end;
      end;
    end;
    result := ALTrim(Result);
  finally
    ALFreeAndNil(LMasterSignatures);
    ALFreeAndNil(LCompareWithSignatures);
  end;
end;

{*******************************************************************}
//we need this function for debuging because their is a bug in delphi
//that make we can not debug inlined var when they are inside the
//begin ... end of the dpr
procedure Kickoff;
begin
  try

    {$IFDEF DEBUG}
    ReportMemoryleaksOnSHutdown := True;
    {$ENDIF}
    SetMultiByteConversionCodePage(CP_UTF8);

    {$REGION 'create local objects'}
    var LParamLst := TALStringListU.Create;
    {$ENDREGION}

    try

      {$REGION 'Init LParamLst'}
      for var I := 1 to ParamCount do
        LParamLst.Add(ParamStr(i));
      {$ENDREGION}

      {$REGION 'Init LAction'}
      var LAction := ansiString(LParamLst.Values['-Action']);
      {$ENDREGION}

      {$REGION 'LAction=Copy'}
      if ALSameText(LAction, 'copy') then begin

        {$REGION 'Init LPlatform'}
        var LPlatform := ALLowerCase(ansiString(LParamLst.Values['-Platform']));
        if (LPlatform <> 'ios') and
           (LPlatform <> 'macos') then raise Exception.Create('Invalid Platforms parameter');
        {$ENDREGION}

        {$REGION 'Init LCustomFrameworksDir'}
        var LCustomFrameworksDir := LParamLst.Values['-CustomFrameworksDir'];
        if LCustomFrameworksDir = '' then raise Exception.Create('CustomFrameworksDir param is mandatory');
        if not TDirectory.exists(LCustomFrameworksDir) then raise Exception.CreateFmt('%s does not exist', [LCustomFrameworksDir]);
        {$ENDREGION}

        {$REGION 'Init LFrameworksDir'}
        var LFrameworksDir := LParamLst.Values['-FrameworksDir'];
        if LFrameworksDir = '' then raise Exception.Create('FrameworksDir param is mandatory');
        if not TDirectory.exists(LFrameworksDir) then raise Exception.CreateFmt('%s does not exist', [LFrameworksDir]);
        {$ENDREGION}

        {$REGION 'Init LCustomFrameworksDir'}
        var LDirectories := TDirectory.GetDirectories(
                              LCustomFrameworksDir, //const Path,
                              '*.framework', // SearchPattern: string;
                              TSearchOption.soAllDirectories); // const SearchOption: TSearchOption)
        for var LDirectory in LDirectories do begin
          if (AlposExIgnoreCaseU('.xcframework', LDirectory) <= 0) or
             ((LPlatform='ios') and (AlposExIgnoreCaseU('\ios-arm64\', LDirectory) > 0)) or
             ((LPlatform='ios') and (AlposExIgnoreCaseU('\ios-arm64_armv7\', LDirectory) > 0)) then begin
            var LdestDir := LFrameworksDir + '\' + ALExtractFileNameU(LDirectory);
            if (TDirectory.Exists(LdestDir)) and
               (not AlEmptyDirectoryU(LdestDir, true)) then RaiseLastOsError;
            if not AlCopyDirectoryU(
                 LDirectory, // SrcDirectory,
                 LFrameworksDir + '\' + ALExtractFileNameU(LDirectory), // DestDirectory: ansiString;
                 true) then // SubDirectory: Boolean;
            raise Exception.Createfmt('Cannot copy %s to %s', [LDirectory, LFrameworksDir + '\' + ALExtractFileNameU(LDirectory)]);
          end;
        end;
        {$ENDREGION}

      end;
      {$ENDREGION}

      {$REGION 'LAction=Compare'}
      if ALSameText(LAction, 'Compare') then begin

        {$REGION 'Init LMasterFile/LMasterSrc'}
        var LMasterFile := LParamLst.Values['-MasterFile'];
        if LMasterFile = '' then raise Exception.Create('MasterFile param is mandatory');
        if not TFile.exists(LMasterFile) then raise Exception.CreateFmt('%s does not exist', [LMasterFile]);
        var LMasterSrc := ALGetStringFromFile(LMasterFile);
        {$ENDREGION}

        {$REGION 'Init LOutputDir/LOutputSrc'}
        var LOutputDir := ExpandFileName(ALTrimU(LParamLst.Values['-OutputDir']));
        if LOutputDir = '' then raise Exception.Create('OutputDir param is mandatory');
        var LOutputCompareFile := LOutputDir + '\' + ALExtractFileNameU(LMasterFile);
        var LOutputCompareSrc: AnsiString := '';
        if TFile.Exists(LOutputCompareFile) then Tfile.Delete(LOutputCompareFile);
        var LPasFiles := TDirectory.GetFiles(
                           LOutputDir, //const Path,
                           '*.pas', // SearchPattern: string;
                           TSearchOption.soTopDirectoryOnly); // const SearchOption: TSearchOption)
        if length(LPasFiles) = 0 then raise Exception.Create('Their is no .pas in OutputDir');
        Var LOutputSrc: AnsiString := '';
        for var I := low(LPasFiles) to High(LPasFiles) do
          LOutputSrc := LOutputSrc + #13#10+#13#10 + ALGetStringFromFile(LPasFiles[i]);
        LOutputSrc := LOutputSrc + #13#10;
        {$ENDREGION}

        {$REGION 'normalize LOutputSrc'}
        //JAccessibilityServiceInfo = interface;//android.accessibilityservice.AccessibilityServiceInfo
        // =>
        //JAccessibilityServiceInfo = interface;
        Var P1 := ALpos(' = interface;//', LOutputSrc);
        while P1 > 0 do begin
          Inc(P1, length(' = interface;'));
          var P2 := ALpos(#13#10, LOutputSrc, P1);
          if P2 < P1 then raise Exception.Create('Error 7227FF98-D555-45BB-9CAC-B3FC59190F34');
          delete(LOutputSrc, P1, P2-P1);
          P1 := ALpos(' = interface;//', LOutputSrc);
        end;
        //----
        //TRegTypes.RegisterType('c:\Dev\MagicFoundation\Alcinoe\Tools\NativeBridgeFileGenerator\Tmp\\JavaInterfaces.JAccessibilityServiceInfo', TypeInfo(c:\Dev\MagicFoundation\Alcinoe\Tools\NativeBridgeFileGenerator\Tmp\\JavaInterfaces.JAccessibilityServiceInfo));
        // =>
        //TRegTypes.RegisterType('ALAndroidFacebookApi.JAccessibilityServiceInfo', TypeInfo(ALAndroidFacebookApi.JAccessibilityServiceInfo));
        P1 := ALpos('TRegTypes.RegisterType(''', LOutputSrc);
        while P1 > 0 do begin
          Inc(P1, length('TRegTypes.RegisterType('''));
          var P2 := ALpos('JavaInterfaces.', LOutputSrc, P1);
          if P2 < P1 then raise Exception.Create('Error 06C293BC-5FFC-4115-B8F2-1CFC7A560EA7');
          inc(P2, length('JavaInterfaces'));
          delete(LOutputSrc, P1, P2-P1);
          insert(ALExtractFileName(ansiString(LMasterFile), true{RemoveFileExt}), LOutputSrc, P1);
          P1 := ALpos('TRegTypes.RegisterType(''', LOutputSrc, P1+1);
        end;
        P1 := ALpos(''', TypeInfo(', LOutputSrc);
        while P1 > 0 do begin
          Inc(P1, length(''', TypeInfo('));
          var P2 := ALpos('JavaInterfaces.', LOutputSrc, P1);
          if P2 < P1 then raise Exception.Create('Error 6835D5D0-5378-4E10-8148-D8A0DA594988');
          inc(P2, length('JavaInterfaces'));
          delete(LOutputSrc, P1, P2-P1);
          insert(ALExtractFileName(ansiString(LMasterFile), true{RemoveFileExt}), LOutputSrc, P1);
          P1 := ALpos(''', TypeInfo(', LOutputSrc, P1+1);
        end;
        //----
        // : instancetype;
        //  =>
        // : Pointer {instancetype};
        LOutputSrc := ALStringReplace(LOutputSrc, ': instancetype;', ': Pointer {instancetype};', [rfReplaceALL]);
        //----
        // TCAAnimation = class(TOCGenericImport<CAAnimationClass, CAAnimation>)  end;
        //  =>
        // TCAAnimation = class(TOCGenericImport<CAAnimationClass, CAAnimation>) end;
        LOutputSrc := ALStringReplace(LOutputSrc, '>)  end;', '>) end;', [rfReplaceALL]);
        //----
        // : BOOL;
        //  =>
        // : Boolean;
        LOutputSrc := ALStringReplace(LOutputSrc, ': BOOL;', ': Boolean;', [rfReplaceALL]);
        {$ENDREGION}

        {$REGION 'Make LOutputCompareSrc'}
        var LMasterLst := TALStringList.Create;
        try
          LMasterLst.Text := LMasterSrc;
          var I := 0;
          while I <= LMasterLst.Count - 1 do begin

            //init LMasterSrcLine
            var LMasterSrcLine := ALTrim(LMasterLst[i]);
            inc(i);

            //Empty LMasterSrcLine
            if LMasterSrcLine = '' then begin
              LOutputCompareSrc := LOutputCompareSrc + #13#10;
              continue;
            end;

            //LMasterSrcLine= {**..**}
            if alpos('{**', ALTrim(LMasterSrcLine)) = 1 then begin
              LOutputCompareSrc := LOutputCompareSrc + LMasterSrcLine + #13#10;
              continue;
            end;

            //If the LMasterSrcLine is present in LOutputSrc
            if (alposExIgnoreCase(' = interface(', LMasterSrcLine) > 0) and (ALpos(';',LMasterSrcLine) <= 0) then begin // FBSDKGraphRequest = interface(IObjectiveC)
              var P2 := alpos('(', LMasterSrcLine); // FBSDKGraphRequest = interface(
              P1 := ALPosExIgnoreCase(ALCopyStr(LMasterSrcLine,1,P2), LOutputSrc);
            end
            else if (alposExIgnoreCase(' = procedure(', LMasterSrcLine) > 0) and (ALpos(';',LMasterSrcLine) >= 0) then begin // FBSDKLoginManagerLoginResultBlock = procedure(result: FBSDKLoginManagerLoginResult; error: NSError) of object;
              P1 := ALPosExIgnoreCase(LMasterSrcLine+#13#10, LOutputSrc);
              if P1 <= 0 then begin
                var P2 := alpos('(', LMasterSrcLine); // FBSDKLoginManagerLoginResultBlock = procedure(
                P1 := ALPosExIgnoreCase(ALCopyStr(LMasterSrcLine,1,P2), LOutputSrc);
              end;
            end
            else begin
              if (ALpos(';', LMasterSrcLine) = length(LMasterSrcLine)) then P1 := ALPosExIgnoreCase(LMasterSrcLine, LOutputSrc)
              else P1 := ALPosExIgnoreCase(LMasterSrcLine+#13#10, LOutputSrc);
            end;
            var P2: integer;
            if P1 > 0 then begin

              //LMasterSrcLine is an interface
              if (alposExIgnoreCase(' = interface(', LMasterSrcLine) > 0) and (ALpos(';',LMasterSrcLine) <= 0) then begin
                var LMasterInterfaceSrc := LMasterSrcLine;
                while Not AlSameText(ALTrim(LMasterLst[i]), 'end;') do begin
                  LMasterInterfaceSrc := LMasterInterfaceSrc + #13#10 + LMasterLst[i];
                  inc(i);
                end;
                LMasterInterfaceSrc := LMasterInterfaceSrc + #13#10 + LMasterLst[i];
                inc(i);
                P2 := alposExIgnoreCase('end;', LOutputSrc, P1);
                if P2 <= P1 then raise Exception.Create('Error 91074DDB-8328-45E7-BC44-E0FC375D499C');
                inc(P2, length('end;'));
                var LCompareWithInterfaceSrc := ALcopyStr(LOutputSrc, P1, P2-P1);
                delete(LOutputSrc, P1, P2 - P1);
                LOutputCompareSrc := LOutputCompareSrc + MergeInterfaceSrc(LMasterInterfaceSrc,LCompareWithInterfaceSrc) + #13#10;
              end

              //LMasterSrcLine is anything else
              else begin
                if (ALpos(';', LMasterSrcLine) = length(LMasterSrcLine)) then P2 := alpos(';', LOutputSrc, P1) + 1
                else P2 := alpos(#13#10, LOutputSrc, P1);
                if P2 <= P1 then raise Exception.Create('Error 9856CE29-C4A9-4CA4-91E1-702AF0909E5E');
                LOutputCompareSrc := LOutputCompareSrc + ALcopyStr(LOutputSrc, P1, P2-P1) + #13#10;
                delete(LOutputSrc, P1, P2 - P1);
              end;

            end
            else begin

              //LMasterSrcLine is an interface
              if (alposExIgnoreCase(' = interface(', LMasterSrcLine) > 0) and (ALpos(';',LMasterSrcLine) <= 0) then begin
                while Not AlSameText(ALTrim(LMasterLst[i]), 'end;') do begin
                  inc(i);
                end;
                inc(i);
              end

              //LMasterSrcLine is anything else
              else begin
                //nothing to do
              end;

            end;

          end;
        finally
          ALFreeAndNil(LMasterLst);
        end;
        {$ENDREGION}

        {$REGION 'save LOutputCompare'}
        while ALPos(#13#10#13#10#13#10, LOutputCompareSrc) > 0 do
          LOutputCompareSrc := ALStringReplace(LOutputCompareSrc, #13#10#13#10#13#10, #13#10#13#10, [RfReplaceALL]);
        ALSaveStringToFile(LOutputCompareSrc, LOutputCompareFile);
        {$ENDREGION}

      end;
      {$ENDREGION}

    finally

      {$REGION 'Free local objects'}
      ALFreeAndNil(LParamLst);
      {$ENDREGION}

    end;

  except
    on E: Exception do begin
      ALWriteln(E.ClassName+': '+E.Message, TALConsoleColor.ccRed);
      Writeln('');
      Writeln('Usage:');
      Writeln('  NativeBridgeFileGeneratorHelper.exe');
      Writeln('    -Action: Actually only "Compare" and "Copy" is supported.');
      Writeln('    -MasterFile: Path of the source file to compare with.');
      Writeln('    -OutputDir: Path where are located all the new generated files.');
      Writeln('    -CustomFrameworksDir: Path of the Custom Frameworks to copy in Frameworks.');
      Writeln('    -FrameworksDir: Path of the Frameworks.');
      Writeln('    -Platform: iOS or MacOS.');
      Writeln('');
      Writeln('Example:');
      Writeln('  NativeBridgeFileGeneratorHelper.exe^');
      Writeln('    -Action="Compare"^');
      Writeln('    -MasterFile="..\..\Source\ALAndroidFacebookApi.pas"^');
      Writeln('    -OutputDir=".\OutputAndroid\"');
      Writeln('');
      Writeln('');
      Writeln('NativeBridgeFileGeneratorHelper failed!');
      Writeln('Press any key to exit');
      Readln;
      halt(1);
    end;
  end;
end;

begin
  kickoff;
end.
