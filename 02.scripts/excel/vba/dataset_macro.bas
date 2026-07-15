'=====================================================================================
' Module:       Dataset
' Version:      V02
' Created:      12/01/2025
' Created by:   Eduardo Cysne
' Last update:  04/03/2026
' Updated by:   Eduardo Cysne
'
' Processes all STAND* reports present in the workbook.
' Generates two tables in the "Dataset" sheet (hidden):
'   - tbl_failures -> log of stoppages by schedule and station
'   - tbl_status   -> production summary by shift/line
'
' Called by:
'   - Workbook_BeforeSave
'   - Workbook_BeforeClose
'
' CHANGE V02:
'   - Loop through ALL STAND* sheets (previously only processed the first one)
'   - Production check across all sheets before processing
'====================================================================================
Option Explicit

Private Const x_password As String = "x123"

Sub report_datasets()

    ' Don't do anything if it's the original document
    If InStr(1, ThisWorkbook.Name, "Report Generator", vbTextCompare) > 0 Then
        Exit Sub
    End If

    Application.ScreenUpdating = False
    ThisWorkbook.Unprotect Password:=x_password

    '------------------------------------------
    ' Check if any STAND sheet has production.
    '------------------------------------------
    Dim has_production  As Boolean
    Dim ws              As Worksheet
    
    has_production = False
    For Each ws In ThisWorkbook.Worksheets
        If ws.Name Like "STAND*" Then
            ws.Unprotect Password:=x_password
            If Val(ws.Range("G93").Value) <> 0 Then
                has_production = True
            End If
            ws.Protect Password:=x_password
        End If
    Next ws
    
    If Not has_production Then GoTo no_production_end

    '---------------------------------------------------
    ' Check if the dataset sheet exists and it's clean
    '---------------------------------------------------
    Dim wsDataset As Worksheet

    On Error Resume Next
    Set wsDataset = ThisWorkbook.Sheets("Dataset")
    On Error GoTo 0

    If wsDataset Is Nothing Then
        Set wsDataset = ThisWorkbook.Sheets.Add
        wsDataset.Name = "Dataset"
    End If

    wsDataset.Unprotect Password:=x_password
    wsDataset.Cells.Clear
    
    ThisWorkbook.Unprotect Password:=x_password

    '--------------------------------------------------------------
    '  1st Dataset - Only the breakdown's data
    '--------------------------------------------------------------
    wsDataset.Range("A1").Value = "ID"
    wsDataset.Range("B1").Value = "date"
    wsDataset.Range("C1").Value = "line"
    wsDataset.Range("D1").Value = "event_time"
    wsDataset.Range("E1").Value = "unplanned_stoppages"
    wsDataset.Range("F1").Value = "planned_stoppages"
    wsDataset.Range("G1").Value = "work_station"
    wsDataset.Range("H1").Value = "machine"
    wsDataset.Range("I1").Value = "failure_type"
    wsDataset.Range("J1").Value = "sub_failure_type"
    wsDataset.Range("K1").Value = "failure_description"

    Dim outRow As Long
    outRow = 2

    '--------------------------
    ' Loop though all sheets
    '--------------------------
    Dim p As Variant
    Dim wb_name As String
    Dim file_name As String
    
    wb_name = ThisWorkbook.Name
    
    For Each ws In ThisWorkbook.Worksheets
        If ws.Name Like "STAND*" Then

            ws.Unprotect Password:=x_password

            ' Jump sheets without production
            If Val(ws.Range("G93").Value) = 0 Then
                ws.Protect Password:=x_password
                GoTo next_sheet_breakdown
            End If

            Dim today As Date
            today = ws.Range("E5").Value

            Dim rng As Range
            Dim r   As Range
            Set rng = ws.Range("I14:AS94")

            For Each r In rng.Rows
                If Application.WorksheetFunction.CountA(r) > 1 Then

                    wsDataset.Cells(outRow, 1).Value = wb_name & ws.Name
                    wsDataset.Cells(outRow, 2).Value = today
                    wsDataset.Cells(outRow, 3).Value = ws.Name

                    With ws.Cells(r.Row, 3)
                        wsDataset.Cells(outRow, 4).Value = .MergeArea.Cells(1, 1).Text
                    End With
                    With ws.Cells(r.Row, 9)
                        wsDataset.Cells(outRow, 5).Value = .MergeArea.Cells(1, 1).Value
                    End With
                    With ws.Cells(r.Row, 11)
                        wsDataset.Cells(outRow, 6).Value = .MergeArea.Cells(1, 1).Value
                    End With
                    With ws.Cells(r.Row, 14)
                        wsDataset.Cells(outRow, 7).Value = .MergeArea.Cells(1, 1).Value
                    End With
                    With ws.Cells(r.Row, 17)
                        wsDataset.Cells(outRow, 8).Value = .MergeArea.Cells(1, 1).Value
                    End With
                    With ws.Cells(r.Row, 20)
                        wsDataset.Cells(outRow, 9).Value = .MergeArea.Cells(1, 1).Value
                    End With
                    With ws.Cells(r.Row, 23)
                        wsDataset.Cells(outRow, 10).Value = .MergeArea.Cells(1, 1).Value
                    End With
                    With ws.Cells(r.Row, 26)
                        wsDataset.Cells(outRow, 11).Value = .MergeArea.Cells(1, 1).Value
                    End With

                    outRow = outRow + 1
                End If
            Next r

            ws.Protect Password:=x_password

        End If
        
next_sheet_breakdown:
    Next ws

    '--------------------------------------------------------------
    ' Cria tbl_falhas e remove linhas sem paragens
    '--------------------------------------------------------------
    Dim lo     As ListObject
    Dim rngTbl As Range

    Set rngTbl = wsDataset.Range("A1").CurrentRegion
    Set lo = wsDataset.ListObjects.Add(xlSrcRange, rngTbl, , xlYes)
    lo.Name = "tbl_falhas"

    Dim k As Long
    With lo.DataBodyRange
        For k = .Rows.count To 1 Step -1
            If (Len(Trim(.Cells(k, 6).Value)) = 0 Or Val(.Cells(k, 6).Value) = 0) And _
               (Len(Trim(.Cells(k, 5).Value)) = 0 Or Val(.Cells(k, 5).Value) = 0) Then
                .Rows(k).Delete
            End If
        Next k
    End With

    ' Adjust columns width
    Dim c As Long
    For c = 1 To wsDataset.Cells(1, wsDataset.Columns.count).End(xlToLeft).Column
            wsDataset.Columns(c).AutoFit
    Next c

    '--------------------------------------------------------------
    '  2nd Dataset - Values for the production status
    '--------------------------------------------------------------
    Dim startRow As Long
    startRow = wsDataset.Range("A10000").End(xlUp).Row + 2

    wsDataset.Cells(startRow, 1).Value = "ID"
    wsDataset.Cells(startRow, 2).Value = "date"
    wsDataset.Cells(startRow, 3).Value = "line"
    wsDataset.Cells(startRow, 4).Value = "shift"
    wsDataset.Cells(startRow, 5).Value = "leader"
    wsDataset.Cells(startRow, 6).Value = "num_operators"
    wsDataset.Cells(startRow, 7).Value = "total_produced"
    wsDataset.Cells(startRow, 8).Value = "nok_parts"
    wsDataset.Cells(startRow, 9).Value = "reworked_parts"
    wsDataset.Cells(startRow, 10).Value = "observations"
    wsDataset.Cells(startRow, 11).Value = "version"
    wsDataset.Cells(startRow, 12).Value = "cycle_time"

    outRow = startRow + 1

    '----------------------------------
    ' Loop through all the STAND sheets
    '----------------------------------
    For Each ws In ThisWorkbook.Worksheets
        If ws.Name Like "STAND*" Then

            ws.Unprotect Password:=x_password
            
            ' Skipt sheets without production
            If Val(ws.Range("G93").Value) = 0 Then
                ws.Protect Password:=x_password
                GoTo next_sheet_status
            End If

            ' shifts
            Dim shift As String
            Select Case True
                Case UCase$(ws.Range("Q5").Value) = "X": shift = "evening"
                Case UCase$(ws.Range("R5").Value) = "X": shift = "morning"
                Case Else: shift = "afternoon"
            End Select

            ' total produced
            Dim total_produced As Variant
            total_produced = ws.Range("G93").Value

            ' NOK Parts
            Dim nok_parts As Variant
            nok_parts = ws.Range("Q99").Value

            ' Reworked Parts
            Dim reworked_parts As Variant
            reworked_parts = ws.Range("W99").Value
    
            ' Cycle time
            Dim cycle_time As Variant
            cycle_time = ws.Range("cycle_time_welding").Value
            
            ' Number of workers
            Dim num_workers As Variant
            num_workers = ws.Range("Q102").Value

            ' Write the status row
            wsDataset.Cells(outRow, 1).Value = wb_name & ws.Name
            wsDataset.Cells(outRow, 2).Value = ws.Range("E5").Value
            wsDataset.Cells(outRow, 3).Value = ws.Name
            wsDataset.Cells(outRow, 4).Value = shift
            wsDataset.Cells(outRow, 5).Value = UCase$(CStr(ws.Range("Z5").Value))
            wsDataset.Cells(outRow, 6).Value = num_workers
            wsDataset.Cells(outRow, 7).Value = ws.Range("E93").Value
            wsDataset.Cells(outRow, 8).Value = total_produced
            wsDataset.Cells(outRow, 9).Value = nok_parts
            wsDataset.Cells(outRow, 10).Value = reworked_parts
            wsDataset.Cells(outRow, 11).Value = ws.Range("AL97").Value
            wsDataset.Cells(outRow, 12).Value = ws.Range("AL97").Value
            wsDataset.Cells(outRow, 13).Value = ws.Range("AL101").Value
            wsDataset.Cells(outRow, 14).Value = ws.Range("AL105").Value
            wsDataset.Cells(outRow, 15).Value = ws.Range("E12").Value
            wsDataset.Cells(outRow, 16).Value = cycle_time

            outRow = outRow + 1
            ws.Protect Password:=x_password

        End If
        
next_sheet_status:
    Next ws

    '-------------------------
    ' Generate the tbl status
    '-------------------------
    
    Dim lo2      As ListObject 'List Object is a table
    Dim rngTbl2  As Range
    Dim lastRow2 As Long

    lastRow2 = outRow - 1

    If lastRow2 > startRow Then
        Set rngTbl2 = wsDataset.Range("A" & startRow & ":P" & lastRow2)
        Set lo2 = wsDataset.ListObjects.Add(xlSrcRange, rngTbl2, , xlYes)
        lo2.Name = "tbl_status"
        rngTbl2.Columns.AutoFit
    End If

    ' Hides the dataset sheet
    wsDataset.Visible = xlSheetHidden

no_production_end:
    ThisWorkbook.Protect Password:=x_password
    Application.ScreenUpdating = True

End Sub