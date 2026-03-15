unit fmx2code.core;

{fmx2code- core unit
github.com/cmr64/fmx2code
main unit containing parser/declerations}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.StrUtils,
  System.Math;

type

  // just a name/value pair straight from the fmx file
  TFMXProperty = record
    Name  : string;
    Value : string;
  end;

  TObjectRec = record
    Name                 : string;
    TypeName             : string;
    ParentName           : string;
    HasParent            : Boolean;
    Depth                : Integer;
    ChildrenCount        : Integer;
    TotalDescendantCount : Integer;
    Properties           : TArray<TFMXProperty>;

    function DisplayText : string;
  end;

  TFMX2CodeObjectNode = class
  public
    Name       : string;
    TypeName   : string;
    Parent     : TFMX2CodeObjectNode;
    Children   : TObjectList<TFMX2CodeObjectNode>;
    Properties : TList<TFMXProperty>;

    constructor Create;
    destructor  Destroy; override;

    function ChildrenCount         : Integer;
    function TotalDescendantCount  : Integer;
    function Depth                 : Integer;
  end;

  TFMX2CodeParser = class
  private
    FRoot     : TFMX2CodeObjectNode;
    FAllNodes : TList<TFMX2CodeObjectNode>;

    function  IsObjectDeclaration(const ALine: string;
                out AName, ATypeName: string): Boolean;
    procedure ParseLines(Lines: TStringList);
    procedure CollectNodes(ANode: TFMX2CodeObjectNode);
    function  FindNode(const AName: string): TFMX2CodeObjectNode;

    function  CleanFloat(const ARaw: string): string;
    function  ConvertSetValue(const APropName, ARaw: string): string;
    function  ConvertValue(const APropName, ARaw: string): string;

    procedure DoGenerateCode(ANode: TFMX2CodeObjectNode;
                IncludeChildren, OnlyProperties: Boolean;
                ALines: TStrings; AIndentLevel: Integer);
  public
    constructor Create;
    destructor  Destroy; override;

    procedure LoadFromString(const AContent: string);
    procedure LoadFromFile(const AFileName: string);
    procedure Clear;

    function GetObjects: TArray<TObjectRec>;
    function GetObjectRec(const AName: string): TObjectRec;

    // set IncludeChildren to also recurse into child objects
    // set OnlyProperties to skip the .Create and .Parent lines
    function GenerateCode(const AObjectName: string;
               IncludeChildren, OnlyProperties: Boolean): TArray<string>;

    property Root : TFMX2CodeObjectNode read FRoot;
  end;

implementation

type
  TStringPair = array[0..1] of string;

const
  // maps a leaf property name to its enum type prefix
  ENUM_MAP: array[0..9] of TStringPair = (
    ('Align',        'TAlignLayout'),
    ('HorzAlign',    'TTextAlign'),
    ('VertAlign',    'TTextAlign'),
    ('Trimming',     'TTextTrimming'),
    ('Visibility',   'TVisibility'),
    ('ScrollDir',    'TScrollDirections'),
    ('Orientation',  'TOrientation'),
    ('Kind',         'TBorderStyle'),
    ('Placement',    'TPlacement'),
    ('AutoSize',     '')
  );

  // maps a property name to the type prefix used for each element in a set
  SET_MAP: array[0..4] of TStringPair = (
    ('InteractiveGestures',  'TInteractiveGesture'),
    ('DataDetectorTypes',    'TDataDetectorType'),
    ('Devices',              'TDeviceKind'),
    ('FontStyle',            'TFontStyle'),
    ('StyleLookup',          '')
  );

function EnumPrefixFor(const ALeafProp: string): string;
var
  I: Integer;
begin
  for I := Low(ENUM_MAP) to High(ENUM_MAP) do
    if ContainsText(ALeafProp, ENUM_MAP[I][0]) then
      Exit(ENUM_MAP[I][1]);
  Result := '';
end;

function SetElemPrefixFor(const APropName: string): string;
var
  I: Integer;
begin
  for I := Low(SET_MAP) to High(SET_MAP) do
    if ContainsText(APropName, SET_MAP[I][0]) then
      Exit(SET_MAP[I][1]);
  Result := '';
end;

function TObjectRec.DisplayText: string;
begin
  if ChildrenCount > 0 then
    Result := Format('%s : %s  (%d children)', [Name, TypeName, ChildrenCount])
  else
    Result := Format('%s : %s', [Name, TypeName]);
end;

constructor TFMX2CodeObjectNode.Create;
begin
  inherited;
  Children   := TObjectList<TFMX2CodeObjectNode>.Create(True);
  Properties := TList<TFMXProperty>.Create;
  Parent     := nil;
end;

destructor TFMX2CodeObjectNode.Destroy;
begin
  Properties.Free;
  Children.Free;
  inherited;
end;

function TFMX2CodeObjectNode.ChildrenCount: Integer;
begin
  Result := Children.Count;
end;

function TFMX2CodeObjectNode.TotalDescendantCount: Integer;
var
  Ch: TFMX2CodeObjectNode;
begin
  Result := Children.Count;
  for Ch in Children do
    Inc(Result, Ch.TotalDescendantCount);
end;

function TFMX2CodeObjectNode.Depth: Integer;
var
  P: TFMX2CodeObjectNode;
begin
  Result := 0;
  P := Parent;
  while P <> nil do
  begin
    Inc(Result);
    P := P.Parent;
  end;
end;

constructor TFMX2CodeParser.Create;
begin
  inherited;
  FRoot     := nil;
  FAllNodes := TList<TFMX2CodeObjectNode>.Create;
end;

destructor TFMX2CodeParser.Destroy;
begin
  Clear;
  FAllNodes.Free;
  inherited;
end;

procedure TFMX2CodeParser.Clear;
begin
  FAllNodes.Clear;
  FreeAndNil(FRoot);
end;

//checks if a trimmed line is "object Name: TType" and pulls out the parts
function TFMX2CodeParser.IsObjectDeclaration(const ALine: string;
  out AName, ATypeName: string): Boolean;
const
  KW = 'object ';
var
  S, Rest: string;
  ColonPos: Integer;
begin
  Result := False;
  S := Trim(ALine);
  if (Length(S) < Length(KW) + 2) or
     (not SameText(Copy(S, 1, Length(KW)), KW)) then
    Exit;

  Rest := Trim(Copy(S, Length(KW) + 1, MaxInt));
  ColonPos := Pos(':', Rest);
  if ColonPos < 2 then Exit;

  AName     := Trim(Copy(Rest, 1, ColonPos - 1));
  ATypeName := Trim(Copy(Rest, ColonPos + 1, MaxInt));
  Result    := (AName <> '') and (ATypeName <> '');
end;

//stack-based parser - push on object, pop on end, collect properties in between
procedure TFMX2CodeParser.ParseLines(Lines: TStringList);
var
  I          : Integer;
  Line, S    : string;
  ObjName    : string;
  ObjType    : string;
  Stack      : TStack<TFMX2CodeObjectNode>;
  NewNode    : TFMX2CodeObjectNode;
  Prop       : TFMXProperty;
  EqPos      : Integer;
  BlockDepth : Integer;
  BlockProp  : string;
  BlockLines : TStringList;
begin
  Clear;

  Stack      := TStack<TFMX2CodeObjectNode>.Create;
  BlockLines := TStringList.Create;
  try
    BlockDepth := 0;
    BlockProp  := '';

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      S    := Trim(Line);
      if S = '' then Continue;

      //inside a multi-line block like a listbox items section
      if BlockDepth > 0 then
      begin
        Inc(BlockDepth, S.CountChar('(') - S.CountChar(')'));
        if BlockDepth <= 0 then
        begin
          // block is done, store it as a single property value
          if Stack.Count > 0 then
          begin
            Prop.Name  := BlockProp;
            Prop.Value := '(' + string.Join(' ', BlockLines.ToStringArray) + ')';
            Stack.Peek.Properties.Add(Prop);
          end;
          BlockDepth := 0;
          BlockProp  := '';
          BlockLines.Clear;
        end else
          BlockLines.Add(S);
        Continue;
      end;

      if IsObjectDeclaration(S, ObjName, ObjType) then
      begin
        NewNode          := TFMX2CodeObjectNode.Create;
        NewNode.Name     := ObjName;
        NewNode.TypeName := ObjType;

        if Stack.Count > 0 then
        begin
          NewNode.Parent := Stack.Peek;
          Stack.Peek.Children.Add(NewNode);
        end else
          FRoot := NewNode; //first object we hit is always the root form

        Stack.Push(NewNode);
        Continue;
      end;

      if SameText(S, 'end') then
      begin
        if Stack.Count > 0 then
          Stack.Pop;
        Continue;
      end;

      if Stack.Count = 0 then Continue;

      EqPos := Pos('=', S);
      if EqPos < 2 then Continue;

      Prop.Name  := Trim(Copy(S, 1, EqPos - 1));
      Prop.Value := Trim(Copy(S, EqPos + 1, MaxInt));

      // value is just '(' means a multi-line block is starting
      if Prop.Value = '(' then
      begin
        BlockDepth := 1;
        BlockProp  := Prop.Name;
        BlockLines.Clear;
      end else
        Stack.Peek.Properties.Add(Prop);
    end;

  finally
    BlockLines.Free;
    Stack.Free;
  end;

  if FRoot <> nil then
    CollectNodes(FRoot);
end;

procedure TFMX2CodeParser.CollectNodes(ANode: TFMX2CodeObjectNode);
var
  Ch: TFMX2CodeObjectNode;
begin
  // skip the root form itself, we only want the actual components
  if ANode <> FRoot then
    FAllNodes.Add(ANode);
  for Ch in ANode.Children do
    CollectNodes(Ch);
end;

function TFMX2CodeParser.FindNode(const AName: string): TFMX2CodeObjectNode;
var
  Node: TFMX2CodeObjectNode;
begin
  for Node in FAllNodes do
    if SameText(Node.Name, AName) then Exit(Node);
  if (FRoot <> nil) and SameText(FRoot.Name, AName) then
    Exit(FRoot);
  Result := nil;
end;

//fmx has enough 0s in floating points to save world hunger, fix them here
function TFMX2CodeParser.CleanFloat(const ARaw: string): string;
var
  D  : Double;
  FS : TFormatSettings;
begin
  FS := TFormatSettings.Create('en-US');
  if not TryStrToFloat(ARaw, D, FS) then
    Exit(ARaw);

  if Frac(D) = 0.0 then
    Exit(IntToStr(Trunc(D)));

  Result := FloatToStrF(D, ffFixed, 15, 6, FS);
  while Result.EndsWith('0') do
    Result := Copy(Result, 1, Length(Result) - 1);
  if Result.EndsWith('.') then
    Result := Copy(Result, 1, Length(Result) - 1);
end;

// turns sets (eg [Item1, Item2]) into TItem.Item1, TItem.Item2 etc
function TFMX2CodeParser.ConvertSetValue(const APropName, ARaw: string): string;
var
  Prefix  : string;
  Inner   : string;
  Elems   : TArray<string>;
  I       : Integer;
  Elem    : string;
  Parts   : TStringList;
begin
  if ARaw = '[]' then Exit('[]');

  Prefix := SetElemPrefixFor(APropName);
  if Prefix = '' then Exit(ARaw);

  Inner := ARaw.Trim;
  if Inner.StartsWith('[') then Inner := Copy(Inner, 2, MaxInt);
  if Inner.EndsWith(']')   then Inner := Copy(Inner, 1, Length(Inner) - 1);

  Elems := Inner.Split([',']);
  Parts := TStringList.Create;
  try
    for I := 0 to High(Elems) do
    begin
      Elem := Trim(Elems[I]);
      if Elem <> '' then
        Parts.Add(Prefix + '.' + Elem);
    end;
    Result := '[' + string.Join(', ', Parts.ToStringArray) + ']';
  finally
    Parts.Free;
  end;
end;

// converts a raw fmx value into delphi code
function TFMX2CodeParser.ConvertValue(const APropName, ARaw: string): string;
var
  FS         : TFormatSettings;
  D          : Double;
  IntVal     : Integer;
  LeafProp   : string;
  DotPos     : Integer;
  EnumPrefix : string;
begin
  Result := ARaw;
  if ARaw = '' then Exit;

  if ARaw.StartsWith('[') then
    Exit(ConvertSetValue(APropName, ARaw));

  if ARaw.StartsWith('''') then
    Exit(ARaw);

  if SameText(ARaw, 'True')  then Exit('True');
  if SameText(ARaw, 'False') then Exit('False');

  FS := TFormatSettings.Create('en-US');
  if ARaw.Contains('.') and TryStrToFloat(ARaw, D, FS) then
    Exit(CleanFloat(ARaw));

  if TryStrToInt(ARaw, IntVal) then
    Exit(ARaw);

  // use the last segment of a dotted name to look up the enum type
  DotPos := APropName.LastIndexOf('.');
  if DotPos >= 0 then
    LeafProp := Copy(APropName, DotPos + 2, MaxInt)
  else
    LeafProp := APropName;

  EnumPrefix := EnumPrefixFor(LeafProp);
  if EnumPrefix <> '' then
    Exit(EnumPrefix + '.' + ARaw);

  Result := ARaw;
end;

procedure TFMX2CodeParser.LoadFromString(const AContent: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AContent;
    ParseLines(Lines);
  finally
    Lines.Free;
  end;
end;

procedure TFMX2CodeParser.LoadFromFile(const AFileName: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    ParseLines(Lines);
  finally
    Lines.Free;
  end;
end;

function TFMX2CodeParser.GetObjects: TArray<TObjectRec>;
var
  I    : Integer;
  Node : TFMX2CodeObjectNode;
  Rec  : TObjectRec;
  J    : Integer;
  Props: TArray<TFMXProperty>;
begin
  SetLength(Result, FAllNodes.Count);

  for I := 0 to FAllNodes.Count - 1 do
  begin
    Node := FAllNodes[I];

    Rec.Name                 := Node.Name;
    Rec.TypeName             := Node.TypeName;
    Rec.Depth                := Node.Depth - 1;
    Rec.ChildrenCount        := Node.ChildrenCount;
    Rec.TotalDescendantCount := Node.TotalDescendantCount;

    if Node.Parent = nil then
    begin
      Rec.ParentName := '';
      Rec.HasParent  := False;
    end
    else if Node.Parent = FRoot then
    begin
      // direct child of the form - parent will be 'Self' in generated code
      Rec.ParentName := '';
      Rec.HasParent  := True;
    end
    else
    begin
      Rec.ParentName := Node.Parent.Name;
      Rec.HasParent  := True;
    end;

    SetLength(Props, Node.Properties.Count);
    for J := 0 to Node.Properties.Count - 1 do
      Props[J] := Node.Properties[J];
    Rec.Properties := Props;

    Result[I] := Rec;
  end;
end;

function TFMX2CodeParser.GetObjectRec(const AName: string): TObjectRec;
var
  Node : TFMX2CodeObjectNode;
  Recs : TArray<TObjectRec>;
  R    : TObjectRec;
begin
  Node := FindNode(AName);
  if Node = nil then
    raise Exception.CreateFmt('Object "%s" was not found in the FMX tree.', [AName]);

  Recs := GetObjects;
  for R in Recs do
    if SameText(R.Name, AName) then Exit(R);

  raise Exception.CreateFmt('Object "%s" not found in object records.', [AName]);
end;

procedure TFMX2CodeParser.DoGenerateCode(ANode: TFMX2CodeObjectNode;
  IncludeChildren, OnlyProperties: Boolean;
  ALines: TStrings; AIndentLevel: Integer);
var
  Ind    : string;
  Prop   : TFMXProperty;
  Ch     : TFMX2CodeObjectNode;
  Parent : string;
  ConVal : string;
begin
  Ind := StringOfChar(' ', AIndentLevel * 2);

  ALines.Add(Format('%s{ %s : %s }', [Ind, ANode.Name, ANode.TypeName]));

  if not OnlyProperties then
  begin
    ALines.Add(Format('%s%s := %s.Create(Self);',
      [Ind, ANode.Name, ANode.TypeName]));

    if ANode.Parent <> nil then
    begin
      if ANode.Parent = FRoot then
        Parent := 'Self'
      else
        Parent := ANode.Parent.Name;
      ALines.Add(Format('%s%s.Parent := %s;', [Ind, ANode.Name, Parent]));
    end;
  end;

  for Prop in ANode.Properties do
  begin
    ConVal := ConvertValue(Prop.Name, Prop.Value);

    // multi-line blocks like listbox items can't be set as a simple assignment
    if Prop.Value.StartsWith('(') then
      ALines.Add(Format('%s// %s.%s := %s; { multi-line block - set at runtime }',
        [Ind, ANode.Name, Prop.Name, ConVal]))
    else
      ALines.Add(Format('%s%s.%s := %s;',
        [Ind, ANode.Name, Prop.Name, ConVal]));
  end;

  ALines.Add('');

  if IncludeChildren then
    for Ch in ANode.Children do
      DoGenerateCode(Ch, True, OnlyProperties, ALines, AIndentLevel);
end;

function TFMX2CodeParser.GenerateCode(const AObjectName: string;
  IncludeChildren, OnlyProperties: Boolean): TArray<string>;
var
  Node  : TFMX2CodeObjectNode;
  Lines : TStringList;
begin
  Node := FindNode(AObjectName);
  if Node = nil then
    raise Exception.CreateFmt(
      'Object "%s" was not found in the FMX tree. ' +
      'Make sure LoadFromString or LoadFromFile was called first.', [AObjectName]);

  Lines := TStringList.Create;
  try
    DoGenerateCode(Node, IncludeChildren, OnlyProperties, Lines, 0);
    Result := Lines.ToStringArray;
  finally
    Lines.Free;
  end;
end;

end.
