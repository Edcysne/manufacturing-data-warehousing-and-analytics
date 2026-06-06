'===================================================================================================================
' Módulo:       Gerar_Relatorio
' Version:      V02
' Created:      13/02/2025
' Created by:   Eduardo Cysne
' Last update:  04/03/2026
' Updated by:   Eduardo Cysne
'
' This is a macro responsible for generating the datasets from the production
'
' MAIN LOGIC:
'   +- Does a CTRL* sheet exist in this workbook?
'   ¦
'   +-- NO  -> First report of the day
'   ¦       -> SaveAs new file on the network (name = date + shift)
'   ¦       -> Add CTRL sheet to the new file
'   ¦       -> Hide all non-essential sheets (without deleting)
'   ¦
'   +-- YES -> Additional report (TL forgot a product, etc.)
'           -> Add new CTRL sheet to the current file
'           -> No SaveAs, no new file
'
' NOTES:
'   - All variables in snake_case
'   - Passwords and paths defined as constandts at the top
'===================================================================================================================

Option Explicit
'C:\Users\amcys\Documents\02.Education\01.Online Education\05.projects\data-warehousing\01. Reports

' -- Constants ----------------------------------------------------------------
Private Const x_password As String = "x0205"
Private Const folders_path As String = "C:\Users\amcys\Documents\02.Education\01.Online Education\05.projects\data-warehousing\01.Reports\Production Reports\"

'===================================================================================================================
' MAIN SUB -> When you click the button to generate a report
'===================================================================================================================
Sub generate_report()

    Application.ScreenUpdating = False
    Application.EnableEvents = False
    Application.DisplayAlerts = False

    '===========================================================
    ' STEP 1 -> Status Validation
    '===========================================================

    ' Search for the worksheet name
    Dim ws_cp    As Worksheet
    Dim wb_main  As Workbook
    
    Set wb_main = ThisWorkbook
    
    On Error Resume Next
    Set ws_cp = wb_main.Worksheets("Add Report") 'The name that appears when you've already generated the first report
        If ws_cp Is Nothing Then
        Set ws_cp = wb_main.Worksheets("Central Panel")
        End If
    On Error GoTo 0

    ' Error handling
    If ws_cp Is Nothing Then
        MsgBox "Não foi possível encontrar o painel de controlo.", vbCritical
        GoTo Finish
    End If

    'Check if it's OK (green with thumbs up)
    If Left(Trim(ws_cp.Range("Z8").Value), 2) <> "OK" Then
        MsgBox "Somente pode-se gerar um report quando o status for OK!", _
               vbExclamation, "Status Inválido"
        GoTo Finish
    End If

    ' Leitura das variáveis do Central Panel (células inalteradas)
    Dim registration_date  As String
    Dim team               As String
    Dim team_leader        As String
    Dim shift              As String
    Dim shift_abc          As String
    Dim car                As String
    Dim part               As String
    Dim version            As String
    Dim spare              As String
    Dim line               As String
    
    registration_date = ws_cp.Range("Q11").Value
    team = ws_cp.Range("Q13").Value
    team_leader = ws_cp.Range("Q15").Value
    shift = ws_cp.Range("Q17").Value
    shift_abc = ws_cp.Range("Q19").Value
    car = ws_cp.Range("R29").Value
    part = ws_cp.Range("U29").Value
    version = ws_cp.Range("X29").Value
    spare = ws_cp.Range("AA29").Value
    line = ws_cp.Range("AD29").Value

    '=============================
    ' STEP 2 - Date Validation
    '=============================
    
    If Trim(registration_date) = "" Then
        MsgBox "No date found! Use the format dd/mm/yyyy (e.g.: 01/12/2026)", _
               vbExclamation, "Missing Date"
        GoTo Finish
    End If
    
    Dim parts() As String
    
    parts = Split(registration_date, "/")
    If UBound(parts) <> 2 Then
        MsgBox "Invalid date format. Please use dd/mm/yyyy.", _
               vbExclamation, "Invalid Date"
        GoTo Finish
    End If

    Dim date_fmt As Date
    
    On Error GoTo data_error
    date_fmt = DateSerial(CLng(parts(2)), CLng(parts(1)), CLng(parts(0)))
    On Error GoTo 0

    Dim str_day         As String
    Dim str_month       As String
    Dim str_year        As String
    Dim month_name      As String

    str_day = Format$(day(date_fmt), "00")
    str_month = Format$(month(date_fmt), "00")
    str_year = CStr(year(date_fmt))

    Select Case month(date_fmt)
        Case 1:  month_name = "Jan"
        Case 2:  month_name = "Feb"
        Case 3:  month_name = "Mar"
        Case 4:  month_name = "Apr"
        Case 5:  month_name = "May"
        Case 6:  month_name = "Jun"
        Case 7:  month_name = "Jul"
        Case 8:  month_name = "Aug"
        Case 9:  month_name = "Sep"
        Case 10: month_name = "Oct"
        Case 11: month_name = "Nov"
        Case 12: month_name = "Dec"
    End Select

    '===========================================================
    ' STEP 3 - Document Name Treatment
    '===========================================================
    Dim part_display          As String
    Dim part_without_space    As String
    Dim line_without_space    As String
    Dim version_part          As String
    Dim spare_part            As String

    ' Only the product name
    part_display = Trim(Replace(part, car, ""))

    part_without_space = Replace(part_display, " ", "")
    line_without_space = Replace(line, " ", "")

    version_part = IIf(Trim(version) = "-" Or Trim(version) = "", "", "_" & Trim(version))
    spare_part = IIf(UCase(Trim(spare)) = "X", "_SPARE", "")

    ' New Sheet Name with CTRL (Control) (31 characters is the maximum of Excel)
    Dim ctrl_sheet_name As String
    
    ctrl_sheet_name = UCase("CTRL " & part_display & " " & car & " " & version & " " & line_without_space)
    If Len(ctrl_sheet_name) > 31 Then ctrl_sheet_name = Left(ctrl_sheet_name, 31)

    ' Layout to use
    Dim layout_chosen As String
    layout_chosen = "Report Layout 1 (WEL)"

    '=====================================================
    ' STEP 4 - MAIN DECISION!
    '          Check if there is any sheet with CTRL
    '          Yes -> Add sheet   No -> SaveAs New File
    '=====================================================
    Dim check_ctrl As Boolean
    Dim ws         As Worksheet

    check_ctrl = False
    For Each ws In ThisWorkbook.Worksheets
        If UCase(Left(ws.Name, 4)) = "CTRL" Then
            check_ctrl = True
            Exit For
        End If
    Next ws

    If Not check_ctrl Then
        '-------------------------------------------------------
        ' BRANCH A - First report of the day?
        '            -> SaveAs for a new folder
        '-------------------------------------------------------
        Call Branch_FirstReport( _
                        date_fmt, str_day, str_month, str_year, month_name, _
                        team, shift, shift_abc, team_leader, _
                        car, part_display, part_without_space, _
                        version, version_part, spare, spare_part, _
                        line, line_without_space, _
                        layout_chosen, ctrl_sheet_name)
    Else
        '-------------------------------------------------------
        ' BRANCH B - Already a CTRL sheet name?
        '            -> Add new sheet with CTRL
        '-------------------------------------------------------
        Call Branch_AdditionalReport( _
                        date_fmt, shift, shift_abc, team_leader, _
                        car, part_display, version, spare, _
                        line, line_without_space, _
                        layout_chosen, ctrl_sheet_name)
    End If

    GoTo Finish

data_error:
    MsgBox "Invalid Date! Verify the format dd/mm/yyyy.", _
           vbExclamation, "Date Error"
GoTo Finish

Finish:
    Application.DisplayAlerts = True
    Application.EnableEvents = True
    Application.ScreenUpdating = True

End Sub


'===================================================================================================================
' BRANCH A -> First Report of the Day
' Save the file as a new document in the destination folder
'===================================================================================================================
Private Sub Branch_FirstReport( _
            date_fmt As Date, _
                    str_day As String, _
                    str_month As String, _
                    str_year As String, month_name As String, _
                    team As String, shift As String, shift_abc As String, team_leader As String, _
                    car As String, part_display As String, part_no_space As String, _
                    version As String, version_part As String, spare As String, spare_part As String, _
                    line As String, line_no_space As String, _
                    layout_chosen As String, ctrl_sheet_name As String)

    
    '-------------------
    'Destination folder
    '-------------------
    Dim dest_folder As String
    dest_folder = folders_path & str_year & "\" & str_month & ". " & month_name & " " & str_year & "\"

    '--------------------------------------------------
    ' Name of the file - Only the date and the shift
    ' Example: 04032026 Shift B
    '--------------------------------------------------
    Dim file_name As String
    file_name = str_day & str_month & str_year & " Shift " & shift_abc

    '--------------------------------------------------
    ' Check Duplicates
    '--------------------------------------------------
    If Dir(dest_folder & file_name & ".xlsm") <> "" Then
        Dim answer As Integer
        answer = MsgBox("There's already a file named " & str_day & " " & month_name & "." & _
                        vbNewLine & vbNewLine & "Do you want to replace it?", _
                        vbQuestion + vbYesNo)
        If answer = vbNo Then
            MsgBox "Operation cancelled. The original file was kept", vbOKOnly
            Exit Sub
        End If
    End If

    '--------------------------------------------------
    ' STEP 1: Hides all sheets
    '--------------------------------------------------
    Dim ws As Worksheet

    ThisWorkbook.Unprotect Password:=x_password
    For Each ws In ThisWorkbook.Worksheets
        ws.Unprotect Password:=x_password
        If ws.Name = "Block Screen" Then
            ws.Visible = xlSheetVisible
        Else
            ws.Visible = xlSheetVeryHidden
        End If
        ws.Protect Password:=x_password
    Next ws
    
    ThisWorkbook.Protect Password:=x_password
    
    Application.EnableEvents = False
    ThisWorkbook.Save
    Application.EnableEvents = True
    
    '--------------------------------------------------
    ' STEP 2: SaveAs in the destination folder
    '--------------------------------------------------

    Application.DisplayAlerts = False
    Application.EnableEvents = False

    ThisWorkbook.SaveAs Filename:=dest_folder & file_name, _
                        FileFormat:=xlOpenXMLWorkbookMacroEnabled, _
                        Password:="", WriteResPassword:="", _
                        ReadOnlyRecommended:=True

    Application.DisplayAlerts = True
    Application.EnableEvents = True

    '--------------------------------------------------
    ' STEP 3: Reopen hidden sheets
    '--------------------------------------------------
    ThisWorkbook.Unprotect Password:=x_password
    For Each ws In ThisWorkbook.Worksheets
        ws.Unprotect Password:=x_password
        ws.Visible = xlSheetVisible
    Next ws

    '--------------------------------------------------
    ' STEP 4: Rename "Central Panel" To "Add Report"
    '--------------------------------------------------
    
    Dim ws_cp_new As Worksheet
    On Error Resume Next
    Set ws_cp_new = ThisWorkbook.Sheets("Central Panel")
    On Error GoTo 0

    If Not ws_cp_new Is Nothing Then

        ' Guarantee the file is unlocked
        ws_cp_new.Visible = xlSheetVisible
        ws_cp_new.Unprotect Password:=x_password

        ' Rename the sheet
        ws_cp_new.Name = "Add Report"

        ' Unblock all the cells (clean reset)
        ws_cp_new.Cells.Locked = False
        ws_cp_new.Activate

        ' Block the cells that can't change
        ' Date, Team, Team Leader, Shift, Shift ABC
        ws_cp_new.Range("Q11:S11").Locked = True   ' Data
        ws_cp_new.Range("Q13:S13").Locked = True   ' Equipa
        ws_cp_new.Range("Q15:S15").Locked = True   ' Team Leader
        ws_cp_new.Range("Q17:S17").Locked = True   ' Turno
        ws_cp_new.Range("Q19:S19").Locked = True   ' Turno ABC
        
        ' Change the button
        Dim btn_gerar As Shape
        On Error Resume Next
        Set btn_gerar = ws_cp_new.Shapes("btn_generate_report")
        On Error GoTo 0
        
        If Not btn_gerar Is Nothing Then
            btn_gerar.TextFrame.Characters.Text = "Add Report"
        End If

        ' Change color to green
        ws_cp_new.Range("M5:AG6").Interior.Color = RGB(10, 158, 28)

        ' Sheet tab to green
        ws_cp_new.Tab.Color = RGB(10, 158, 28)

        ' Change the central pannel range also to green
        With ws_cp_new.Range("M5:AG39")
            .Borders(xlEdgeTop).LineStyle = xlContinuous
            .Borders(xlEdgeTop).Weight = xlMedium
            .Borders(xlEdgeTop).Color = RGB(10, 158, 28)

            .Borders(xlEdgeBottom).LineStyle = xlContinuous
            .Borders(xlEdgeBottom).Weight = xlMedium
            .Borders(xlEdgeBottom).Color = RGB(10, 158, 28)

            .Borders(xlEdgeLeft).LineStyle = xlContinuous
            .Borders(xlEdgeLeft).Weight = xlMedium
            .Borders(xlEdgeLeft).Color = RGB(10, 158, 28)

            .Borders(xlEdgeRight).LineStyle = xlContinuous
            .Borders(xlEdgeRight).Weight = xlMedium
            .Borders(xlEdgeRight).Color = RGB(10, 158, 28)
        End With
        
        ' UserInterfaceOnly: blocked cells to the user
        ws_cp_new.Protect Password:=x_password, UserInterfaceOnly:=True

    End If

    '--------------------------------------------------
    ' STEP 5: Add a CTRL sheet
    ' (sub shared with Branch B)
    '--------------------------------------------------
    Call AddSheetCTRL( _
            date_fmt, shift, shift_abc, team_leader, _
            car, part_display, version, spare, _
            line, line_no_space, _
            layout_chosen, ctrl_sheet_name)

    '-----------------------------------------------------------------
    ' STEP 6: Apply final visibility
    ' Visible: CTRL* + Data + Add Report
    ' Everything else: VeryHidden
    ' NOTE: checks both possible names for the control sheet
    '       to ensure it works even if the rename fails
    '-----------------------------------------------------------------
    ThisWorkbook.Unprotect Password:=x_password
    For Each ws In ThisWorkbook.Worksheets
        ws.Unprotect Password:=x_password
        Select Case True
            Case UCase(Left(ws.Name, 4)) = "CTRL": ws.Visible = xlSheetVisible
            Case ws.Name = "Report Data": ws.Visible = xlSheetVisible
            Case ws.Name = "Add Report": ws.Visible = xlSheetVisible
            Case ws.Name = "Central Panel": ws.Visible = xlSheetVisible
            Case ws.Name = "Block Screen": ws.Visible = xlSheetHidden
            Case Else: ws.Visible = xlSheetVeryHidden
        End Select
        ws.Protect Password:=x_password
    Next ws
    ThisWorkbook.Protect Password:=x_password, Structure:=True

    ' Activate the new CTRL Sheet
    ThisWorkbook.Sheets(ctrl_sheet_name).Activate

End Sub


'===================================================================================================================
' BRANCH B - Additional report
' At least one CTRL* already exists -> adds a new sheet to the current file
' No SaveAs, no new file, no changes to other sheets
'===================================================================================================================
Private Sub Branch_AdditionalReport( _
        date_fmt As Date, _
        shift As String, shift_abc As String, team_leader As String, _
        car As String, part_display As String, version As String, _
        spare As String, line As String, line_no_space As String, _
        layout_chosen As String, ctrl_sheet_name As String)


    ' Check duplicates
    If SheetExists(ThisWorkbook, ctrl_sheet_name) Then
        MsgBox "A sheet '" & ctrl_sheet_name & "' already exists in this file." & vbNewLine & _
               "Please check if this report has already been generated.", _
               vbExclamation, "Duplicate Report"
        Exit Sub
    End If

    ' Unprotect the sheet
    ThisWorkbook.Unprotect Password:=x_password

    'Add sheet
    Call AddSheetCTRL( _
            date_fmt, shift, shift_abc, team_leader, _
            car, part_display, version, spare, _
            line, line_no_space, _
            layout_chosen, ctrl_sheet_name)

    ' Ensure visibility and activate
    ThisWorkbook.Sheets(ctrl_sheet_name).Visible = xlSheetVisible
    ThisWorkbook.Sheets(ctrl_sheet_name).Activate
    ThisWorkbook.Protect Password:=x_password, Structure:=True
        
    Application.EnableEvents = False
    ThisWorkbook.Save
    Application.EnableEvents = True
    MsgBox "Report '" & ctrl_sheet_name & "' added successfully!", _
            vbInformation, "Done"

End Sub


'===================================================================================================================
' AddSheetCTRL -> Sub shared by Branch A and Branch B
'
' Responsibilities:
'   1. Copies the layout template to the end of the workbook
'   2. Pastes all header values
'   3. Pastes the station data (table from the Data sheet)
'   4. Adds the "Delete Report" button
'   5. Renames and protects the sheet
'===================================================================================================================
Private Sub AddSheetCTRL( _
        date_fmt As Date, _
        shift As String, shift_abc As String, team_leader As String, _
        car As String, part_display As String, version As String, _
        spare As String, line As String, line_no_space As String, _
        layout_chosen As String, ctrl_sheet_name As String)

    '---------------------------
    ' Copy the Layout Template
    '---------------------------
    Dim ws_layout As Worksheet
    
    On Error Resume Next
    Set ws_layout = ThisWorkbook.Sheets(layout_chosen)
    On Error GoTo 0
    
    ws_layout.Unprotect Password:=x_password

    ws_layout.Visible = xlSheetVisible
    ws_layout.Copy After:=ThisWorkbook.Sheets(ThisWorkbook.Sheets.count)
    ws_layout.Visible = xlSheetHidden

    Dim ws_report As Worksheet
    Set ws_report = ThisWorkbook.Sheets(ThisWorkbook.Sheets.count)
    ws_report.Unprotect Password:=x_password

    '--------------------------------------------------
    ' Paste header values
    '--------------------------------------------------
    ws_report.Range("AH2").Value = part_display & " " & line
    ws_report.Range("E5").Value = date_fmt
    ws_report.Range("Z5").Value = team_leader
    ws_report.Range("AL5").Value = shift_abc
    ws_report.Range("E12").Value = version

    ' Cell indicatin SPARE Part
    If layout_chosen = "Report Layout 1 (SOL)" Then
        ws_report.Range("G12").Value = spare
    End If

    ' Clean the Shifts checkboxes
    ws_report.Range("Q5").Value = ""
    ws_report.Range("R5").Value = ""
    ws_report.Range("S5").Value = ""

    Select Case LCase(shift)
        Case "morning": ws_report.Range("R5").Value = "X"
        Case "afternoon": ws_report.Range("S5").Value = "X"
        Case Else: ws_report.Range("Q5").Value = "X" 'Evening
    End Select

    '--------------------------------------------------
    ' Paste station data (table from the "Data" sheet)
    '--------------------------------------------------
    Dim kpis_name      As String
    Dim table_name     As String
    Dim stations_name  As String
    Dim tbl_stations   As ListObject
    Dim part_stations  As String
    Dim line_stations  As String

    If layout_chosen = "Report Layout 1 (SOL)" Then
        kpis_name = ws_report.Range("Q114").Value
    Else
        kpis_name = ws_report.Range("X2").Value
    End If
        
    'Built to account for "ICE" and similar typologies
    part_stations = LCase(Replace(part_display, " ", "_"))
    line_stations = LCase(Replace(line, " ", "_"))
    stations_name = Replace(part_stations, "-", "") & "_" & car & "_" & line_stations
    table_name = stations_name & "_stations"
    
    'If the table does not exist, fail silently and continue
    On Error Resume Next
    Set tbl_stations = ThisWorkbook.Worksheets("Data").ListObjects(table_name)
    On Error GoTo 0
    
    If Not tbl_stations Is Nothing Then
        Dim data_arrays As Variant
        data_arrays = tbl_stations.DataBodyRange.Value
        Dim first_row As Long
        Dim r As Long, c As Long
        first_row = 101
        For r = 1 To UBound(data_arrays, 1)
            For c = 1 To UBound(data_arrays, 2)
                ws_report.Cells(first_row, 3 + (c - 1)).Value = data_arrays(r, c)
            Next c
            first_row = first_row + 2
        Next r
    End If

    '--------------------------
    ' Delete button creation
    '---------------------------
    Dim btn_left   As Double
    Dim btn_top    As Double
    Dim btn_width  As Double
    Dim btn_height As Double

    'Button Size
    btn_width = 150
    btn_height = 40

    ' Button Placement
    btn_left = ws_report.Range("AU2").Left + (ws_report.Range("AU2").Width - btn_width) / 2 + 65
    btn_top = ws_report.Range("AU2").Top + (ws_report.Range("AU2").Height - btn_height) / 2 + 25

    Dim btn_shape As Shape
    Set btn_shape = ws_report.Shapes.AddShape(msoShapeRoundedRectangle, btn_left, btn_top, btn_width, btn_height)

    With btn_shape
        .Adjustments(1) = 0.2

        .Fill.Solid
        .Fill.ForeColor.RGB = RGB(227, 0, 0)

        ' Borders
        .line.Visible = msoTrue
        .line.ForeColor.RGB = RGB(139, 0, 0)
        .line.Weight = 1

        ' Shadow
        With .Shadow
            .Visible = msoTrue
            .Transparency = 0.6
            .Size = 100
            .Blur = 3
            .OffsetX = 1
            .OffsetY = 2
        End With

        With .TextFrame
            .HorizontalAlignment = xlHAlignCenter
            .VerticalAlignment = xlVAlignCenter
            With .Characters
                .Text = "Deletar Report"
                .Font.Color = RGB(255, 255, 255)
                .Font.Bold = True
                .Font.Size = 12
            End With
        End With

        .OnAction = "DeleteReport"
        .Name = "BtnDelete"
    End With
    
    '--------------------------------------------------
    ' Changes the "Generate Report" button text to
    ' "Add Report" on the newly created sheet
    '--------------------------------------------------
    Dim btn_generate As Shape
    
    On Error Resume Next
    Set btn_generate = ws_report.Shapes("btn_generate_report")
    On Error GoTo 0
    
    If Not btn_generate Is Nothing Then
        btn_generate.TextFrame.Characters.Text = "Add Report"
    End If
    
    '--------------------------------------------------
    ' Rename and protect the new sheet
    '--------------------------------------------------
    ws_report.Name = ctrl_sheet_name
    ws_report.Protect Password:=x_password
    
End Sub


'===================================================================================================================
' DeleteReport - When the red button is clicked
' Identify where the button was clicked and delete the sheet
'===================================================================================================================
Sub DeleteReport()

    Dim ws_actual As Worksheet
    Set ws_actual = ActiveSheet

    'Only delete CTRL sheets - Safety Layer
    If UCase(Left(ws_actual.Name, 4)) <> "CTRL" Then
        MsgBox "This button can only be used on report sheets.", vbExclamation
        Exit Sub
    End If
    
    ' Mandatory confirmation - prevents accidental deletion
    Dim answer As Integer
    answer = MsgBox("Are you sure you want to delete the report:" & vbNewLine & _
                    "'" & ws_actual.Name & "'?" & vbNewLine & vbNewLine & _
                    "This action cannot be undone.", _
                    vbCritical + vbYesNo, "Delete Report")
    If answer = vbNo Then Exit Sub

    ' Blocks to delete the only CTRL sheet.
    ' It doesn´t make sense to exclude all CTRL sheets. The user can generate a new report if that's the case.
    Dim ctrl_count As Integer
    Dim ws         As Worksheet
    ctrl_count = 0

    For Each ws In ThisWorkbook.Worksheets
        If UCase(Left(ws.Name, 4)) = "CTRL" Then
            ctrl_count = ctrl_count + 1
        End If
    Next ws

    If ctrl_count = 1 Then
        MsgBox "Cannot delete the only existing report." & vbNewLine & _
               "If you wish to start over, close the file without saving.", _
               vbExclamation, "Operation Not Allowed"
        Exit Sub
    End If

    ' Delete the sheet and goes to the next CTRL Sheet
    Application.DisplayAlerts = False
    ThisWorkbook.Unprotect Password:=x_password
    ws_actual.Delete
    Application.DisplayAlerts = True

    For Each ws In ThisWorkbook.Worksheets
        If UCase(Left(ws.Name, 4)) = "CTRL" Then
            ws.Activate
            Exit For
        End If
    Next ws

    ThisWorkbook.Protect Password:=x_password, Structure:=True
    
    Application.EnableEvents = False
    ThisWorkbook.Save
    Application.EnableEvents = True
    MsgBox "Report Deleted Succesfully", vbInformation
    
End Sub

'Private Function to help identify existing sheets before creating a new one
Private Function SheetExists(wb As Workbook, sheetName As String) As Boolean
        
        Dim ws As Worksheet
        On Error Resume Next
        Set ws = wb.Sheets(sheetName)
        SheetExists = Not (ws Is Nothing)
        On Error GoTo 0

End Function
