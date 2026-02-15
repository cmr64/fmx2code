unit Unit3;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo.Types,
  FMX.StdCtrls, FMX.Layouts, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo,
  FMX.ListBox, FMX.Edit, core;

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
    procedure btnLoadClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure lbxObjectsItemClick(const Sender: TCustomListBox;
      const Item: TListBoxItem);
    procedure btnGenerateClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    FParser : TParser;
    FGenerator : TGenerator;
  end;

var
  Form3: TForm3;

implementation

{$R *.fmx}

procedure TForm3.btnGenerateClick(Sender: TObject);
begin
FGenerator := TGenerator.Create;
var LCode : TStringList := FGenerator.Generate(FParser.ExtractRecord(lbxObjects.Selected.TagString), ChkGenerateChildren.IsChecked, chkGenerateCreate.IsChecked);
for var i  := 0 to LCode.Count -1 do begin
memCode.Lines.Add(LCode[i]);
end;
end;

procedure TForm3.btnLoadClick(Sender: TObject);
begin
var LDialog : TOpenDialog := TOpenDialog.Create(nil);
LDialog.Filter := 'FMX forms|.fmx|';
try
  LDialog.Execute;
  var LPath : String := LDialog.FileName;
finally
 LDialog.Free;
end;
end;

procedure TForm3.FormCreate(Sender: TObject);
begin
laySetup.Visible := false;
end;

procedure TForm3.lbxObjectsItemClick(const Sender: TCustomListBox;
  const Item: TListBoxItem);
begin
laySetup.Visible := true;
end;

end.
