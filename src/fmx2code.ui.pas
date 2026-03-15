unit fmx2code.ui;

{fmx2code- ui unit
github.com/cmr64/fmx2code
main ui for accessing fmx2code}

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo.Types,
  FMX.StdCtrls, FMX.Layouts, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,
  FMX.ListBox, FMX.Edit, fmx2code.core;

type
  TForm3 = class(TForm)
    memCode: TMemo;
    Layout1: TLayout;
    btnLoad: TButton;
    Layout2: TLayout;
    lblLoaded: TLabel;
    Layout3: TLayout;
    Label1: TLabel;
    edtSearch: TEdit;
    lbxObjects: TListBox;
    laySetup: TLayout;
    btnGenerate: TButton;
    ChkGenerateChildren: TCheckBox;
    chkGenerateCreate: TCheckBox;
    btnClear: TButton;
    procedure btnLoadClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure lbxObjectsItemClick(const Sender: TCustomListBox;
      const Item: TListBoxItem);
    procedure btnGenerateClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
  private
    { Private declarations }
    procedure LoadObjects;
  public
    { Public declarations }
  end;

var
  Form3: TForm3;
  FParser : TFMX2CodeParser;

implementation

{$R *.fmx}

procedure TForm3.btnClearClick(Sender: TObject);
begin
memCode.Lines.Clear;
end;

procedure TForm3.btnGenerateClick(Sender: TObject);
begin
var LName : String := TMetropolisUIListBoxItem(lbxObjects.Selected).Title;

var LCode : TArray<String> := FParser.GenerateCode(LName, ChkGenerateChildren.IsChecked, chkGenerateCreate.IsChecked);

for var i  := 0 to High(Lcode) -1  do memCode.Lines.Add(LCode[i])
end;

procedure TForm3.btnLoadClick(Sender: TObject);
begin
var LDialog : TOpenDialog := TOpenDialog.Create(nil);
LDialog.Filter := 'FMX forms|*.fmx|';
try
  LDialog.Execute;
  var LPath : String := LDialog.FileName;
  lblLoaded.Text := 'Currently loaded: ' + LPath;
  FParser.LoadFromFile(LPath);
  LoadObjects;
finally
 LDialog.Free;
end;
end;

procedure TForm3.FormCreate(Sender: TObject);
begin
FParser := TFMX2CodeParser.Create;
laySetup.Visible := false;
end;

procedure TForm3.lbxObjectsItemClick(const Sender: TCustomListBox;
  const Item: TListBoxItem);
begin
laySetup.Visible := true;
end;

procedure TForm3.LoadObjects;
begin
var LList : TArray<TObjectRec>;
LList := FParser.GetObjects;

for var i  := 0 to High(LList) - 1 do begin
//metropolis item because i dont feel like creating 30 child objects for labels
  var LItem : TMetropolisUIListBoxItem := TMetropolisUIListBoxItem.Create(lbxObjects);
  LItem.Parent := lbxObjects;
  LItem.Height := 55;
  Litem.Title := LList[i].Name;
  LItem.SubTitle := Format('Type: %s', [LList[i].TypeName]);
  Litem.Description := Format('Children: %u' , [LList[i].ChildrenCount]);
end;

end;

end.
