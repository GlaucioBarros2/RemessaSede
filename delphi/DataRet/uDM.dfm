object dmDados: TdmDados
  OldCreateOrder = False
  Height = 200
  Width = 400
  object ApolloConnection1: TApolloConnection
    Port = 5002
    Host = '127.0.0.1'
    User = ''
    Password = ''
    Active = False
    ServerName = 'datanet'
    TimeOut = 120000
    Version = 'ApolloConnection 7.5.1.0'
    Left = 40
    Top = 24
  end
  object ApolloEnv1: TApolloEnv
    ApolloConnection = ApolloConnection1
    ApplyTo = [atLocal, atServer]
    Left = 40
    Top = 88
  end
  object ATTit: TApolloTable
    ApolloConnection = ApolloConnection1
    AccessMethod = amServer
    DatabaseName = 'DATANET'
    ExtraIndexes.Strings = (
      'saindtit.nsx')
    FieldDefs = <>
    IndexDefs = <>
    IndexName = 'saindtit.nsx'
    TableName = 'SACADTIT.DBF'
    OEMTranslate = False
    TableType = ttSXNSX
    Left = 160
    Top = 24
  end
  object ATEmp: TApolloTable
    ApolloConnection = ApolloConnection1
    AccessMethod = amServer
    DatabaseName = 'DATANET'
    FieldDefs = <>
    IndexDefs = <>
    TableName = 'SACADEMP.DBF'
    OEMTranslate = False
    TableType = ttSXNSX
    Left = 160
    Top = 88
  end
end
