object frmMain: TfrmMain
  Left = 0
  Top = 0
  BorderStyle = bsToolWindow
  Caption = 'BalLeitor - Balanco de Estoque'
  ClientHeight = 80
  ClientWidth = 200
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  Visible = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object TrayIcon1: TTrayIcon
    PopupMenu = PopupMenu1
    OnDblClick = TrayIcon1DblClick
    Left = 16
    Top = 16
  end
  object Timer1: TTimer
    Enabled = False
    OnTimer = Timer1Timer
    Left = 64
    Top = 16
  end
  object PopupMenu1: TPopupMenu
    Left = 16
    Top = 64
    object mnuProcessarAgora: TMenuItem
      Caption = 'Processar agora'
      OnClick = mnuProcessarAgoraClick
    end
    object mnuSeparador1: TMenuItem
      Caption = '-'
    end
    object mnuEncerrar: TMenuItem
      Caption = 'Encerrar'
      OnClick = mnuEncerrarClick
    end
  end
end
