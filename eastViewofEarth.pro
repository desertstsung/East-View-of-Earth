pro def_sysv
  compile_opt idl2, hidden

  utcDate4C = ['0131', '0228', '0229', '0331', '0430', '0531', '0630', $
    '0731', '0831', '0930', '1031', '1130', '1231']
  bjtDate4C = ['0201', '0301', '0301', '0401', '0501', '0601', '0701', $
    '0801', '0901', '1001', '1101', '1201', '0101']
  utcHour4C = ['00', '01', '02', '03', '04', '05', '06', '07', $
    '08', '09', '10', '11', '12', '13', '14', '15', $
    '16', '17', '18', '19', '20', '21', '22', '23']
  bjtHour4C = ['08', '09', '10', '11', '12', '13', '14', '15', $
    '16', '17', '18', '19', '20', '21', '22', '23', $
    '00', '01', '02', '03', '04', '05', '06', '07']

  DEFSYSV, '!allQuality', ['Low', 'Normal', 'High'], 1
  DEFSYSV, '!lut', HASH(!allQuality, [100, 350, 600]), 1
  DEFSYSV, '!hourConvert', HASH(utcHour4C, bjtHour4C), 1
  DEFSYSV, '!dayAdd1', ['16', '17', '18', '19', '20', '21', '22', '23'], 1
  DEFSYSV, '!yearAdd1', ['1231'], 1
  DEFSYSV, '!dateConvert', HASH(utcDate4C, bjtDate4C), 1
end

function utc2Bjt, utc
  compile_opt idl2, hidden

  utcYear = utc.Substring(0, 3)
  utcMonth = utc.Substring(4, 5)
  utcDay = utc.Substring(6, 7)
  utcHour = utc.Substring(8, 9)
  minute = utc.Substring(10, 11)

  bjtHour = (!hourConvert)[utcHour]

  if !dayAdd1.HasValue(utcHour) then begin

    if (!dateConvert).HasKey(utcMonth + utcDay) then begin

      leapYear = ['2020', '2024', '2028', '2032', '2036', '2040']
      if leapYear.HasValue(utcYear) and utcMonth + utcDay eq '0228' then begin
        bjtMonth = '02' & bjtDay = '29'
      endif else begin
        bjtDate = (!dateConvert)[utcMonth + utcDay]
        bjtMonth = bjtDate.Substring(0, 1)
        bjtDay = bjtDate.Substring(2, 3)
      endelse

      if !yearAdd1.HasValue(utcMonth + utcDay) then begin
        yearTemp = utcYear.ToInteger() + 1S
        bjtYear = yearTemp.ToString()
      endif else begin
        bjtYear = utcYear
      endelse

    endif else begin
      dayTemp = utcDay.ToInteger() + 1S
      bjtDay = dayTemp.ToString()
      bjtDay = bjtDay.Strlen() eq 1 ? '0' + bjtDay : bjtDay
      bjtMonth = utcMonth
      bjtYear = utcYear
    endelse

  endif else begin
    bjtDay = utcDay
    bjtMonth = utcMonth
    bjtYear = utcYear
  endelse

  RETURN, bjtYear + bjtMonth + bjtDay + bjtHour + minute
end

function removeFilled, value, removeValue
  compile_opt idl2, hidden

  RETURN, UINT(value ne removevalue) * value
end

function hdf2Jpg, fn, imgQlt
  compile_opt idl2, hidden
  DLM_LOAD,'HDF5','JPEG'

  res = (!lut)[imgQlt]

  blu = h5_getdata(fn, '/NOMChannel01')
  red = h5_getdata(fn, '/NOMChannel02')
  nir = h5_getdata(fn, '/NOMChannel03')

  arr = MAKE_ARRAY([3, (nir.DIM)[0], (nir.DIM)[1]], type = nir.TYPECODE)
  arr[0, *, *] = nir
  arr[1, *, *] = red
  arr[2, *, *] = blu

  nirSort = nir.Sort()
  nirRemove = nirSort.Filter('removeFilled', 65535)
  minNIR = nirSort[FLOOR(nir.LENGTH * 0.02)]
  maxNIR = nirRemove[FLOOR(nirRemove.LENGTH * 0.98)]

  redSort = red.Sort()
  redRemove = redSort.Filter('removeFilled', 65535)
  minRED = redSort[FLOOR(red.LENGTH * 0.02)]
  maxRED = redRemove[FLOOR(redRemove.LENGTH * 0.98)]

  bluSort = blu.Sort()
  bluRemove = bluSort.Filter('removeFilled', 65535)
  minBLU = bluSort[FLOOR(blu.LENGTH * 0.02)]
  maxBLU = bluRemove[FLOOR(bluRemove.LENGTH * 0.98)]

  nir = (red = (blu = !NULL))
  nirSort = (redSort = (bluSort = !NULL))
  nirRemove = (redRemove = (bluRemove = !NULL))

  minValue = [minNIR, minRED, minBLU]
  maxValue = [maxNIR, maxRED, maxBLU]

  utcDateTime = (FILE_BASENAME(fn)).Extract('20[1,2][0-9][0,1][0-9][0-3][0-9][0-9][0-9][0-9][0-9]')
  bjtDateTime = utc2Bjt(utcDateTime)
  date = bjtDateTime.Substring(0, 3) + '-' + $
    bjtDateTime.Substring(4, 5) + '-' + $
    bjtDateTime.Substring(6, 7)
  time = bjtDateTime.Substring(8, 9) + ':' + $
    bjtDateTime.Substring(10, 11)
  oImage = IMAGE(arr, /order, /buffer, $
    max_value = maxValue, min_value = minValue, $
    title = 'Shot on FY4A-AGRI' + STRING(10B) + date $
    + '  ' + time + '(BJT)')
  ofn = 'FY4A-AGRI_' + date + '_' + bjtDateTime.Substring(8, 9) + $
    bjtDateTime.Substring(10, 11) + '.JPG'
  oImage.Save, ofn, resolution = res
  oImage.Close

  RETURN, ofn
end

pro hdf2Gif, dir, imgQlt, dlyTim, delHdf, delJpg
  compile_opt idl2, hidden
  DLM_LOAD, 'GIF'
  CD, dir

  hdfGroup = FILE_SEARCH(dir, '*.HDF')
  utcBegin = (FILE_BASENAME(hdfGroup[0])).Extract('20[1,2][0-9][0,1][0-9][0-3][0-9][0-9][0-9][0-9][0-9]')
  utcEnd = (FILE_BASENAME(hdfGroup[-1])).Extract('20[1,2][0-9][0,1][0-9][0-3][0-9][0-9][0-9][0-9][0-9]')
  bjtBegin = utc2Bjt(utcBegin)
  bjtEnd = utc2Bjt(utcEnd)
  dateBegin = bjtBegin.Substring(0,3) + '-' + $
    bjtBegin.Substring(4,5) + '-' + $
    bjtBegin.Substring(6,7)
  dateEnd = bjtEnd.Substring(0,3) + '-' + $
    bjtEnd.Substring(4,5) + '-' + $
    bjtEnd.Substring(6,7)

  if dateBegin ne dateEnd then begin
    out_gif = dateBegin + '_' + dateEnd + '.GIF'
  endif else begin
    out_gif = dateBegin + '.GIF'
  endelse

  foreach hdffn, hdfGroup do begin
    out_jpg = hdf2Jpg(hdffn, imgQlt)
    if delHdf then FILE_DELETE, hdffn
    READ_JPEG, out_jpg, arrOrg
    arr = COLOR_QUAN(arrOrg[0, *, *], arrOrg[1, *, *], arrOrg[2, *, *], red, grn, blu)
    arr = arr.Reform()
    write_gif, out_gif, arr, red, grn, blu, /multi, $
      delay_time = dlyTim, repeat_count = 0
    if delJpg then FILE_DELETE, out_jpg
  endforeach

  write_gif, out_gif, /close
  s = DIALOG_MESSAGE('Done!', /inf)
end

pro eastViewofEarth_event, event
  compile_opt idl2, hidden

  common region, $
    inputStr, inputText, $
    qltStr, qltList, $
    delay, delayInput, $
    delHdf, delJpg, $
    start

  WIDGET_CONTROL, event.ID, get_uvalue = uvalue

  authorStr = 'Author: deserts Tsung' + STRING(10B) + $
    'Chengdu University of Information Technology' + $
    STRING(10B) + 'Contact me: rpc.tsung@gmail.com'
  prgrmStr = 'Input: Directory exists FY4A-AGRI HDFs(1/2/4KM supported)' $
    + STRING(10B) $
    + 'Output: Time series GIF'

  case uvalue of
    'author': inf = DIALOG_MESSAGE(authorStr, /inf)
    'prgrm': inf = DIALOG_MESSAGE(prgrmStr, /inf)
    'selectInput':begin
      inputStr = DIALOG_PICKFILE(/directory)
      WIDGET_CONTROL, inputText, set_value = inputStr
    end
    'qltList':begin
      idx = event.index
      qltStr = !allQuality[idx]
    end
    'delayInput':begin
      WIDGET_CONTROL, delayInput, get_value = delay
    end
    'delHdf_yes': delHdf = 1B
    'delHdf_no': delHdf = 0B
    'delJpg_yes': delJpg = 1B
    'delJpg_no': delJpg = 0B
    'start': hdf2Gif, inputStr, qltStr, delay, delHdf, delJpg
    else: RETURN
  endcase
end

pro eastViewofEarth
  compile_opt idl2, hidden

  def_sysv
  common region, $
    inputStr, inputText, $
    qltStr, qltList, $
    delay, delayInput, $
    delHdf, delJpg, $
    start

  base = WIDGET_BASE(title = 'East View of Earth', $
    xsize = 340, ysize = 220, mbar = mbar)

  about = WIDGET_BUTTON(mbar, value = 'About', /menu)
  author = WIDGET_BUTTON(about, $
    value = 'Author', uvalue = 'author')
  prgrm = WIDGET_BUTTON(about, $
    value = 'This Program', uvalue = 'prgrm')

  inputStr = ''
  selectInput = WIDGET_BUTTON(base, $
    xsize = 85, ysize = 25, $
    xoffset = 235, yoffset = 4, $
    value = 'Select Input', uvalue = 'selectInput')
  inputText = WIDGET_TEXT(base, $
    xsize = 35, ysize = 1, $
    xoffset = 10, yoffset = 5, $
    value = inputStr)

  qltStr = 'Low'
  qltLabel = WIDGET_LABEL(base, $
    xsize = 80, ysize = 20, $
    xoffset = 12, yoffset = 50, $
    value = 'Image Quality:')
  qltList = WIDGET_DROPLIST(base, $
    xsize = 100, ysize = 24, $
    xoffset = 100, yoffset = 47, $
    value = !allQuality, uvalue = 'qltList')

  delay = 20S
  dlyLabel = WIDGET_LABEL(base, $
    xsize = 100, ysize = 20, $
    xoffset = 12, yoffset = 80, $
    value = 'Delay Time(0.01s):')
  delayInput = WIDGET_SLIDER(base, $
    xsize = 180, ysize = 25, $
    xoffset = 130, yoffset = 70, $
    max = 200, min = 10, $
    value = delay, uvalue = 'delayInput')

  delHdfLabel = WIDGET_LABEL(base, $
    xsize = 70, ysize = 20, $
    xoffset = 12, yoffset = 110, $
    value = 'Delete HDF')
  delHdfBase = WIDGET_BASE(base, $
    xsize = 150, ysize = 20, $
    xoffset = 90, yoffset = 105, $
    /exclusive, /row)
  delHdf_yes = WIDGET_BUTTON(delHdfBase, /no_release, $
    value='Yes', uvalue='delHdf_yes')
  delHdf_no = WIDGET_BUTTON(delHdfBase, /no_release, $
    value='No', uvalue='delHdf_no')
  WIDGET_CONTROL, delHdf_yes, /set_button
  delHdf = 1B

  delJpgLabel = WIDGET_LABEL(base, $
    xsize = 70, ysize = 20, $
    xoffset = 12, yoffset = 140, $
    value = 'Delete JPG')
  delJpgBase = WIDGET_BASE(base, $
    xsize = 150, ysize = 20, $
    xoffset = 90, yoffset = 135, $
    /exclusive, /row)
  delJpg_yes = WIDGET_BUTTON(delJpgBase, /no_release, $
    value='Yes', uvalue='delJpg_yes')
  delJpg_no = WIDGET_BUTTON(delJpgBase, /no_release, $
    value='No', uvalue='delJpg_no')
  WIDGET_CONTROL, delJpg_yes, /set_button
  delJpg = 1B

  start = WIDGET_BUTTON(base, $
    xsize = 310, ysize = 25, $
    xoffset = 10, yoffset = 165, $
    value = 'Just Do It!', uvalue = 'start')

  WIDGET_CONTROL, base, /REALIZE
  XMANAGER, 'EastViewofEarth', base, /NO_BLOCK
end