unit core;

//fmx2code
//github.com/cmr64/fmx2code
//parser unit- parse file into list of objects to display

interface

uses Sysutils, Generics.Collections, Classes, RegularExpressions, StrUtils;

type

TObjectRec = record
  Name : String;
  ParentName : String;
  Position : Integer;
  HasChildren, IsChild : Boolean;
  ChildrenCount : Integer;
  ChildrenList : TList<TObjectRec>;
  Properties : TDictionary<string, string>;
end;

TDisplayRec = record
  Name : String;
  ChildrenCount : Integer;
  TagString : String; //used for searching, contains properties etc
end;

TParser = class
private
  FLines : TStringList;
  FDic : TDictionary<String, TObjectRec>;
  FObjRegex : TRegex;
  function BuildObject(APos : Integer): TObjectRec;
  const OBJECTREGEX = '\bobject\b';
  const ENDREGEX = '\bend\b';
public
  constructor Create(ALines : TStringList);
  function Parse: TList<TObjectRec>;
  function ExtractRecord(AKey : String): TObjectRec;
  destructor Destroy;
end;

TGenerator = class
private
  const
  CREATE = 'var %s : %s := %s.Create(%s)';
  PARENT = '%s.Parent := %s';
public
  function Generate(AObject : TObjectRec; AGenerateChildren, AOnlyProperties : Boolean): TStringList;
end;

implementation

{ TParser }

function TParser.BuildObject(APos: Integer): TObjectRec;
begin
  var LObjName: String := SplitString(FLines[APos], ':')[0];
  Delete(LObjName, 1, 7); // remove "object"

  if FDic.ContainsKey(LObjName) then Exit; // already added

  var LEndRegex: TRegex := TRegex.Create(ENDREGEX);
  var LIndex: Integer := APos + 1;
  var LDepth: Integer := 0;

  Result.Name := LObjName;
  Result.Position := APos;
  Result.Properties := TDictionary<String, String>.Create;

  while LIndex < FLines.Count do
  begin
    var LLine := Trim(FLines[LIndex]);

    if FObjRegex.IsMatch(LLine) then
    begin
      Inc(LDepth); // entering child object
    end
    else if LEndRegex.IsMatch(LLine) then
    begin
      if LDepth = 0 then
        Break
      else
        Dec(LDepth); // exiting  child object
    end
    else if (LDepth = 0) and (Pos('=', LLine) > 0) then
    begin
      var LSplit: TArray<string> := SplitString(LLine, '=');
      if Length(LSplit) = 2 then
        Result.Properties.Add(Trim(LSplit[0]), Trim(LSplit[1]));
    end;
    Inc(LIndex);
  end;
end;

constructor TParser.Create(ALines: TStringList);
begin
FLines := ALines;
FDic := TDictionary<string, TObjectRec>.Create;
end;

destructor TParser.Destroy;
begin
FLines.Free;
FDic.Clear;
FDic.Free;
end;

function TParser.ExtractRecord(AKey: String): TObjectRec;
begin
if FDic.ContainsKey(AKey) then FDic.TryGetValue(AKey, Result)
else raise exception.Create('Key not found')
end;

function TParser.Parse: TList<TObjectRec>;
begin
FObjRegex := TRegex.Create(OBJECTREGEX);

for var i := 0 to FLines.Count - 1 do begin
  if FObjRegex.IsMatch(FLines[i]) then BuildObject(i);
end;
end;

{ TGenerator }

function TGenerator.Generate(AObject: TObjectRec; AGenerateChildren,
  AOnlyProperties: Boolean): TStringList;
begin

end;

end.
