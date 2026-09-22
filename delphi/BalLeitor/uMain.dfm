object frmMain: TfrmMain
  Left = 0
  Top = 0
  BorderStyle = bsToolWindow
  Caption = 'BalLeitor - Balanco de Estoque'
  ClientHeight = 200
  ClientWidth = 599
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
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
  object ApolloConnection1: TApolloConnection
    Port = 5002
    Host = '127.0.0.1'
    User = ''
    Password = ''
    Active = True
    ServerName = 'datanet'
    TimeOut = 120000
    Version = 'ApolloConnection 7.5.1.0'
    Left = 528
    Top = 72
  end
  object ApolloEnv1: TApolloEnv
    ApolloConnection = ApolloConnection1
    ApplyTo = [atLocal, atServer]
    Left = 528
    Top = 16
  end
  object ATCadPro: TApolloTable
    ApolloConnection = ApolloConnection1
    AccessMethod = amServer
    DatabaseName = 'DATANET'
    ExtraIndexes.Strings = (
      'saindpro.nsx')
    FieldDefs = <
      item
        Name = 'CODPRO'
        DataType = ftString
        Size = 6
      end
      item
        Name = 'DTCADPRO'
        DataType = ftDate
      end
      item
        Name = 'DTULTVEN'
        DataType = ftDate
      end
      item
        Name = 'DTVENCTO'
        DataType = ftDate
      end
      item
        Name = 'DESCPRO'
        DataType = ftString
        Size = 41
      end
      item
        Name = 'LOTMERC'
        DataType = ftString
        Size = 78
      end
      item
        Name = 'UNIDPRO'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'CODPRI'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'CODGRU'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'CODSUB'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'NUMPRATEL'
        DataType = ftString
        Size = 6
      end
      item
        Name = 'CLASSFISC'
        DataType = ftString
        Size = 10
      end
      item
        Name = 'CEST'
        DataType = ftString
        Size = 7
      end
      item
        Name = 'CODFOR'
        DataType = ftString
        Size = 6
      end
      item
        Name = 'REF_FABR'
        DataType = ftString
        Size = 13
      end
      item
        Name = 'OPCAO'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'NUMPONTO'
        DataType = ftFloat
      end
      item
        Name = 'PESOPRO'
        DataType = ftFloat
      end
      item
        Name = 'PESOBRU'
        DataType = ftFloat
      end
      item
        Name = 'DIAESTMIN'
        DataType = ftSmallint
      end
      item
        Name = 'DIAESTMAX'
        DataType = ftSmallint
      end
      item
        Name = 'EMBPAD'
        DataType = ftFloat
      end
      item
        Name = 'PRAZOMED'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'CONTROLE'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'GRUPOCOM'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'VENDEMORC'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'REPASSE'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMNORMAL'
        DataType = ftFloat
      end
      item
        Name = 'VARDIVATC'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'PREVENDA'
        DataType = ftFloat
      end
      item
        Name = 'PREVENDA2'
        DataType = ftFloat
      end
      item
        Name = 'PREVENDA3'
        DataType = ftFloat
      end
      item
        Name = 'PRE_HASH'
        DataType = ftFloat
      end
      item
        Name = 'PRECOANT'
        DataType = ftFloat
      end
      item
        Name = 'PRECOFAB'
        DataType = ftFloat
      end
      item
        Name = 'DESCBONIF'
        DataType = ftFloat
      end
      item
        Name = 'PCTLUCRO'
        DataType = ftFloat
      end
      item
        Name = 'PCTFRETE'
        DataType = ftFloat
      end
      item
        Name = 'PCTVENDA'
        DataType = ftFloat
      end
      item
        Name = 'PCTCOMISS'
        DataType = ftFloat
      end
      item
        Name = 'SALDESTOQ'
        DataType = ftFloat
      end
      item
        Name = 'SALDESTOQ2'
        DataType = ftFloat
      end
      item
        Name = 'SAL_HASH'
        DataType = ftFloat
      end
      item
        Name = 'SALMESANT'
        DataType = ftFloat
      end
      item
        Name = 'ESTOQMAX'
        DataType = ftFloat
      end
      item
        Name = 'ESTOQMIN'
        DataType = ftFloat
      end
      item
        Name = 'VENDASDIA'
        DataType = ftFloat
      end
      item
        Name = 'FALTASDIA'
        DataType = ftFloat
      end
      item
        Name = 'FALTASMES'
        DataType = ftFloat
      end
      item
        Name = 'ACUMES0'
        DataType = ftFloat
      end
      item
        Name = 'ACUMES1'
        DataType = ftFloat
      end
      item
        Name = 'ACUMES2'
        DataType = ftFloat
      end
      item
        Name = 'ACUMES3'
        DataType = ftFloat
      end
      item
        Name = 'VENMES0'
        DataType = ftFloat
      end
      item
        Name = 'VENMES1'
        DataType = ftFloat
      end
      item
        Name = 'VENMES2'
        DataType = ftFloat
      end
      item
        Name = 'VENMES3'
        DataType = ftFloat
      end
      item
        Name = 'VENMES4'
        DataType = ftFloat
      end
      item
        Name = 'VENMES5'
        DataType = ftFloat
      end
      item
        Name = 'VENMES6'
        DataType = ftFloat
      end
      item
        Name = 'SALMES0'
        DataType = ftFloat
      end
      item
        Name = 'SALMES1'
        DataType = ftFloat
      end
      item
        Name = 'SALMES2'
        DataType = ftFloat
      end
      item
        Name = 'SALMES3'
        DataType = ftFloat
      end
      item
        Name = 'SALMES4'
        DataType = ftFloat
      end
      item
        Name = 'SALMES5'
        DataType = ftFloat
      end
      item
        Name = 'SALMES6'
        DataType = ftFloat
      end
      item
        Name = 'COMPMES1'
        DataType = ftFloat
      end
      item
        Name = 'COMPMES2'
        DataType = ftFloat
      end
      item
        Name = 'COMPMES3'
        DataType = ftFloat
      end
      item
        Name = 'COMPMES4'
        DataType = ftFloat
      end
      item
        Name = 'COMPMES5'
        DataType = ftFloat
      end
      item
        Name = 'COMPMES6'
        DataType = ftFloat
      end
      item
        Name = 'ABCFNMES1'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ABCFNMES2'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ABCFNMES3'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ABCFSMES1'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ABCFSMES2'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ABCFSMES3'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'TOTFAMES1'
        DataType = ftFloat
      end
      item
        Name = 'TOTFAMES2'
        DataType = ftFloat
      end
      item
        Name = 'TOTFAMES3'
        DataType = ftFloat
      end
      item
        Name = 'TOTVEMES1'
        DataType = ftFloat
      end
      item
        Name = 'TOTVEMES2'
        DataType = ftFloat
      end
      item
        Name = 'TOTVEMES3'
        DataType = ftFloat
      end
      item
        Name = 'TOTVEMES4'
        DataType = ftFloat
      end
      item
        Name = 'TOTVEMES5'
        DataType = ftFloat
      end
      item
        Name = 'TOTVEMES6'
        DataType = ftFloat
      end
      item
        Name = 'BLOQUEIO'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'QTD_DIASA'
        DataType = ftFloat
      end
      item
        Name = 'QTD_DIASB'
        DataType = ftFloat
      end
      item
        Name = 'QTD_DIASC'
        DataType = ftFloat
      end
      item
        Name = 'QTD_DIASD'
        DataType = ftFloat
      end
      item
        Name = 'QTD_DIASE'
        DataType = ftFloat
      end
      item
        Name = 'ULTCOMPRA'
        DataType = ftDate
      end
      item
        Name = 'DTULTREA'
        DataType = ftDate
      end
      item
        Name = 'ULTCONFER'
        DataType = ftDate
      end
      item
        Name = 'QTDCOMPRA'
        DataType = ftFloat
      end
      item
        Name = 'ULTQTDCOM'
        DataType = ftFloat
      end
      item
        Name = 'CLASFISC'
        DataType = ftString
        Size = 10
      end
      item
        Name = 'CAMPANHA0'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'CAMPANHA1'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'CAMPANHA2'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'CAMPANHA3'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'CAMPANHA4'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'CAMPANHA5'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'CAMPANHA6'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ALIQUOIPI'
        DataType = ftFloat
      end
      item
        Name = 'ALI_IPIVE'
        DataType = ftFloat
      end
      item
        Name = 'CUSTO_ATC'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'CUSTOCOM'
        DataType = ftFloat
      end
      item
        Name = 'CUSTOMED'
        DataType = ftFloat
      end
      item
        Name = 'CUSTODOL'
        DataType = ftFloat
      end
      item
        Name = 'CODAPR'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'CODATC'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'PROACESAI'
        DataType = ftString
        Size = 6
      end
      item
        Name = 'PRECOAPR'
        DataType = ftFloat
      end
      item
        Name = 'PRECO_APR'
        DataType = ftFloat
      end
      item
        Name = 'UFICMRT01'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS01'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET01'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB01'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT02'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS02'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET02'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB02'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT03'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS03'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET03'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB03'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT04'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS04'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET04'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB04'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT05'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS05'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET05'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB05'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT06'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS06'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET06'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB06'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT07'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS07'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET07'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB07'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT08'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS08'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET08'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB08'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT09'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS09'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET09'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB09'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT10'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS10'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET10'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB10'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT11'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS11'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET11'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB11'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT12'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS12'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET12'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB12'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT13'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS13'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET13'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB13'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT14'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS14'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET14'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB14'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT15'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS15'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET15'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB15'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT16'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS16'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET16'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB16'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT17'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS17'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET17'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB17'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT18'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS18'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET18'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB18'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT19'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS19'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET19'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB19'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT20'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS20'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET20'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB20'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT21'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS21'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET21'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB21'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT22'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS22'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET22'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB22'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT23'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS23'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET23'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB23'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT24'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS24'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET24'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB24'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT25'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS25'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET25'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB25'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT26'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS26'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET26'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB26'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'UFICMRT27'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'OPERFIS27'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'ICMSRET27'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'SITTRIB27'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'MENSPRO'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'DESCCOMP'
        DataType = ftFloat
      end
      item
        Name = 'CODBARRA'
        DataType = ftString
        Size = 14
      end
      item
        Name = 'CODBARRAV'
        DataType = ftString
        Size = 14
      end
      item
        Name = 'CODPROLAB'
        DataType = ftString
        Size = 3
      end
      item
        Name = 'SIT_TRIB'
        DataType = ftString
        Size = 2
      end
      item
        Name = 'SALDOANT2'
        DataType = ftFloat
      end
      item
        Name = 'COD_ABC'
        DataType = ftString
        Size = 9
      end
      item
        Name = 'FRACAO'
        DataType = ftSmallint
      end
      item
        Name = 'DEC24891'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'DEC27541'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'DTULTENT'
        DataType = ftDate
      end
      item
        Name = 'VBCSTRET'
        DataType = ftFloat
      end
      item
        Name = 'VICMSSUBS'
        DataType = ftFloat
      end
      item
        Name = 'VICMSSTRE'
        DataType = ftFloat
      end
      item
        Name = 'PRECOCUP'
        DataType = ftFloat
      end
      item
        Name = 'MEDIA180'
        DataType = ftFloat
      end
      item
        Name = 'DIASESTOQ'
        DataType = ftSmallint
      end
      item
        Name = 'QTDEVEND'
        DataType = ftFloat
      end
      item
        Name = 'QTDE_PED'
        DataType = ftFloat
      end
      item
        Name = 'APRE_PED'
        DataType = ftString
        Size = 1
      end
      item
        Name = 'PREV_PED'
        DataType = ftDate
      end>
    IndexDefs = <
      item
        Name = '1'
        Fields = 'CODPRO'
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '2'
        Fields = 'DESCPRO'
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '3'
        Expression = 'CODPRI + DESCPRO'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '4'
        Expression = 'CODFOR + STR(TOTFAMES1)'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '5'
        Expression = 'CODFOR + STR(TOTVEMES1)'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '6'
        Expression = 'CODFOR + DESCPRO'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '7'
        Expression = '((ACUMES1 + ACUMES2 + ACUMES3)/3) * -1'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '8'
        Expression = 'VENMES1 * -1'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '9'
        Expression = 'CODGRU + ABCFNMES1 + DESCPRO'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '10'
        Expression = 'NUMPRATEL + DESCPRO'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '11'
        Expression = 'CODGRU + CODSUB + DESCPRO'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '12'
        Expression = 'CODFOR + CODGRU + CODSUB'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '13'
        Expression = 'CODGRU + DESCPRO'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '14'
        Fields = 'CODBARRA'
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '15'
        Expression = 'CODFOR+CODPRO'
        Options = [ixExpression]
        Source = 'SAINDPRO.NSX'
      end
      item
        Name = '16'
        Fields = 'CODBARRAV'
        Source = 'SAINDPRO.NSX'
      end>
    IndexName = 'saindpro.nsx'
    TableName = 'SACADPRO.DBF'
    OEMTranslate = False
    TableType = ttSXNSX
    Left = 128
    Top = 16
  end
  object ATCadMov: TApolloTable
    ApolloConnection = ApolloConnection1
    AccessMethod = amServer
    DatabaseName = 'DATANET'
    ExtraIndexes.Strings = (
      'saindmov.nsx')
    FieldDefs = <>
    IndexDefs = <
      item
        Name = '1'
        Expression = 'CODPRO + DTOS(DTMOV)'
        Options = [ixExpression]
        Source = 'SAINDMOV.NSX'
      end
      item
        Name = '2'
        Expression = 'NUMDOC+SERIE+NATUMOV+NUMPRENOT'
        Options = [ixExpression]
        Source = 'SAINDMOV.NSX'
      end
      item
        Name = '3'
        Expression = 'DTOS(DTMOV) + CODPRO'
        Options = [ixExpression]
        Source = 'SAINDMOV.NSX'
      end
      item
        Name = '4'
        Fields = 'CODPROM'
        Source = 'SAINDMOV.NSX'
      end
      item
        Name = '5'
        Expression = 'CODFOR+CODGRU+CODSUB+CODPRO'
        Options = [ixExpression]
        Source = 'SAINDMOV.NSX'
      end
      item
        Name = '6'
        Fields = 'DESCPRO'
        Source = 'SAINDMOV.NSX'
      end
      item
        Name = '7'
        Fields = 'NUMCUPOM'
        Source = 'SAINDMOV.NSX'
      end
      item
        Name = '8'
        Expression = 'NUMDOC+CODPRO+CODAPR'
        Options = [ixExpression]
        Source = 'SAINDMOV.NSX'
      end
      item
        Name = '9'
        Expression = 'CODEMI+NUMDOC+NATUMOV'
        Options = [ixExpression]
        Source = 'SAINDMOV.NSX'
      end
      item
        Name = '10'
        Expression = 'CODEMI+NUMDOC+CODPRO'
        Options = [ixExpression]
        Source = 'SAINDMOV.NSX'
      end>
    IndexName = 'saindmov.nsx'
    TableName = 'SACADMOV.DBF'
    OEMTranslate = False
    TableType = ttSXNSX
    Left = 200
    Top = 16
  end
  object ATCadApr: TApolloTable
    ApolloConnection = ApolloConnection1
    AccessMethod = amServer
    DatabaseName = 'DATANET'
    ExtraIndexes.Strings = (
      'saindapr.nsx')
    FieldDefs = <>
    IndexDefs = <
      item
        Name = '1'
        Fields = 'CODAPR'
        Source = 'SAINDAPR.NSX'
      end
      item
        Name = '2'
        Fields = 'APRESENTA'
        Source = 'SAINDAPR.NSX'
      end>
    IndexName = 'saindapr.nsx'
    TableName = 'SACADAPR.DBF'
    OEMTranslate = False
    TableType = ttSXNSX
    Left = 272
    Top = 16
  end
  object ATCadEm2: TApolloTable
    ApolloConnection = ApolloConnection1
    AccessMethod = amServer
    DatabaseName = 'DATANET'
    FieldDefs = <>
    IndexDefs = <>
    TableName = 'SACADEM2.DBF'
    OEMTranslate = False
    TableType = ttSXNSX
    Left = 344
    Top = 16
  end
end
