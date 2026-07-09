'===================================================================================================================
' ThisWorkbook
' Version:      V02
' Created:      12/01/2025
' Created by:   Eduardo Cysne
' Last update:  04/03/2026
' Updated by:   Eduardo Cysne
'
' Workbook lifecycle: Open, BeforeSave, BeforeClose
'
' OPENING LOGIC:
'   +- Has CTRL* sheets? (= today's output file)
'   ¦
'   +-- YES -> Shows CTRL* + Data + Central Panel (TL can fill Central Panel to add a report)
'   ¦
'   +-- NO  -> It's the Matrix template file
'               -> Shows Central Panel + Map B1 + Map B2
'
' CLOSING LOGIC:
'   +- Is it the Matrix file? -> Just saves (no lock-down)
'   +- Is it an output file?  -> Builds datasets + full lock-down
'===================================================================================================================
Option Explicit

Private Const x_password As String = "x123"

'-------------------------------------------------------------------------------
' The leaders might forget to click a button and generate the reports
' This was created to generate the reports automatically everytime they save the document
'-------------------------------------------------------------------------------
Private Sub Workbook_BeforeSave(ByVal SaveAsUI As Boolean, Cancel As Boolean)

    If Not Application.EnableEvents Then Exit Sub
    
    Application.EnableEvents = False
    Call report_datasets
    Application.EnableEvents = True
    
    
End Sub

'-------------------------------------------
' Open - sets correct visibility on open
'-------------------------------------------
Private Sub Workbook_Open()

    Application.ScreenUpdating = False
    Application.EnableEvents = True
    
    Dim ws As Worksheet

    On Error Resume Next
    ThisWorkbook.Unprotect Password:=x_password
    For Each ws In ThisWorkbook.Worksheets
        If Not ws.Name Like "Block Screen" Then
            ws.Unprotect Password:=x_password
            ws.Visible = xlSheetHidden
        Else
            ws.Visible = xlSheetVisible
        End If
    Next ws
    On Error GoTo 0

    ' Simple logic to identify which document is the current one
    ' If it has CTRL sheets, then is an ongoing document, otherwise it's the original ome
    Dim is_output_file As Boolean
    Dim is_original    As Boolean

    is_output_file = False
    is_original = (InStr(1, ThisWorkbook.Name, "Report Generator", vbTextCompare) > 0)

    For Each ws In ThisWorkbook.Worksheets
        If UCase(Left(ws.Name, 4)) = "CTRL" Then
            is_output_file = True
            Exit For
        End If
    Next ws

    'Apply different visibility allowances for each document type (original or ongoing production report)
    For Each ws In ThisWorkbook.Worksheets
        Select Case True

            ' Ongoing Report
            Case is_output_file And (UCase(Left(ws.Name, 4)) = "CTRL" Or ws.Name = "Report Data" Or ws.Name = "Add Report")
                ws.Visible = xlSheetVisible

            ' Original
            Case is_original And (ws.Name = "Central Panel" Or ws.Name = "Ship 1" Or ws.Name = "Ship 2" Or ws.Name = "Ship 3")
                ws.Visible = xlSheetVisible

        End Select
    
        ws.Protect Password:=x_password
        
    Next ws
    
    ' Handle Add Report separately, once
    Dim ws_add As Worksheet
    
    On Error Resume Next
    Set ws_add = ThisWorkbook.Sheets("Add Report")
    On Error GoTo 0

    If Not ws_add Is Nothing Then
        ws_add.Unprotect Password:=x_password
        ws_add.Protect Password:=x_password, UserInterfaceOnly:=True
    End If

    ThisWorkbook.Protect Password:=x_password, Structure:=True, Windows:=False

    ' Activate the correct sheets for each document type
    If is_output_file Then
        For Each ws In ThisWorkbook.Worksheets
            If UCase(Left(ws.Name, 4)) = "CTRL" Then
                ws.Activate
                Exit For
            End If
        Next ws
    Else
        On Error Resume Next
        ThisWorkbook.Sheets("Central Panel").Activate
        On Error GoTo 0
    End If
    
    On Error Resume Next
    Dim ws_block As Worksheet
    Set ws_block = ThisWorkbook.Sheets("Block Screen")
    If Not ws_block Is Nothing Then
        ws_block.Visible = xlSheetHidden
    End If
    On Error GoTo 0


    Application.EnableEvents = True
    Application.ScreenUpdating = True

End Sub

'-----------------------------------
' BeforeClose - lock-down on close
'-----------------------------------
Private Sub Workbook_BeforeClose(Cancel As Boolean)

    If InStr(1, ThisWorkbook.Name, "Report Generator", vbTextCompare) > 0 Then
        ThisWorkbook.Save
        Exit Sub
    End If

    Application.ScreenUpdating = False
    Application.EnableEvents = False
    Application.DisplayAlerts = False

    ' Unprotect everything to allow modifications
    ThisWorkbook.Unprotect Password:=x_password
    Dim ws As Worksheet
    
    For Each ws In ThisWorkbook.Worksheets
        ws.Unprotect Password:=x_password
        ws.Visible = xlSheetVisible
    Next ws
    
    ' Build datasets before closing, just to ensure.
    ' Sometimes production floor can just close the documents and not save them.
    Call report_datasets
    
    ' Now handle Add Report separately, once
    Dim ws_add As Worksheet
    
    On Error Resume Next
    Set ws_add = ThisWorkbook.Sheets("Add Report")
    On Error GoTo 0
    
    If Not ws_add Is Nothing Then
        ws_add.Unprotect Password:=x_password
        ws_add.Protect Password:=x_password, UserInterfaceOnly:=True
    End If
    
    ' The dataset macro protects the file, unprotecting it again
    ThisWorkbook.Unprotect Password:=x_password

    ' Activate "Report Lock" as the landing sheet on next open
    Dim ws_lock As Worksheet
    Set ws_lock = ThisWorkbook.Worksheets("Block Screen")
    
    ws_lock.Visible = xlSheetVisible
    ws_lock.Activate

    ' Don't make them very hidden, sometimes you need to make changes in specific reports
    For Each ws In ThisWorkbook.Worksheets
        If ws.Name <> "Block Screen" Then
            ws.Visible = xlSheetHidden
        End If
        ws.Protect Password:=x_password
    Next ws

    ThisWorkbook.Protect Password:=x_password, Structure:=True, Windows:=False

    Application.ScreenUpdating = True
    Application.EnableEvents = True
    Application.DisplayAlerts = True

End Sub
