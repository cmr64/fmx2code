program fmx2code;

uses
  System.StartUpCopy,
  FMX.Forms,
  fmx2code.ui in 'fmx2code.ui.pas' {Form3},
  fmx2code.core in 'fmx2code.core.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
