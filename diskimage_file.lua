function calc(line) return line % 8 * 1024 + math.floor(line / 64) * 40 + math.floor((line%64) / 8) * 128 + 8192 end

function dprint(debugstr,astr) if debugstr then print(astr) end end
function remprint(...) print(...) end
function remprint(...) end
function rem(...) end

function printt(a) if #a==2 then io.write("{") for i,j in pairs(a) do if type(j)=="table" then printt(j) else io.write(hex(j)..",") end end io.write("}\n")  else for i,j in pairs(a) do print(i,j) end end end

function tsoffset(t,s,c) if s==nil then print("SECTOR IS NIL") print(debug.traceback()) end c=c or 0 return (t*16+s)*256+c end

function getdiskbyte(t,s,c)     return mydisk:byte(tsoffset(t,s,c+1)) end
function getdiskbytepair(t,s,c) return mydisk:byte(tsoffset(t,s,c+1)),mydisk:byte(tsoffset(t,s,c+2)) end
function getdisk2bytes(t,s,c)   return mydisk:byte(tsoffset(t,s,c+1))+mydisk:byte(tsoffset(t,s,c+2))*256 end


function iif(a,b,c) if a then return b else return c end end

function hex(a,digits,prefix) digits=digits or 2 prefix=prefix or "" if a==nil then return nil end return string.format(prefix.."%0"..digits.."x",a) end
function hexx(a,digits,prefix) prefix=prefix or "0x" return hex(a,digits,"0x") end
function hexpair(a,b) return "("..hex(a)..","..hex(b)..")" end

function stripfileheaderandextra(datafile) 
  if datafile==nil then return nil end
  dataaddr=datafile:byte(0+1)+datafile:byte(1+1)*256 
  datalen=datafile:byte(2+1)+datafile:byte(3+1)*256  
  if datalen==0 then datalen=datafile:len() - 4 end  
  print ("BLOAD ADDR=" .. 
          hexpair(datafile:byte(0+1),datafile:byte(1+1))   .."  "..
          hex(datafile:byte(0+1)+datafile:byte(1+1)*256,4) .."  "..
          " DATA LENGTH="..hexpair(datafile:byte(2+1),datafile:byte(3+1))..
          " DATA LENGTH="..hex(datalen,4)) 
  print("LEN ORIG:",hex(datafile:len())) 
  datafile=datafile:sub(4+1,4+1+(datalen-1)) 
  print("LEN AFTER:",hex(datafile:len())) 
  return datafile,dataaddr,datalen 
end

function gettslist(t,s,debugstr) 
local total=0 sectorcount=0 local tslist={} 
local expectedtslistoffset
local foundtslistoffset
while true do 
  -- check to see if t is nil or we are at the end of the list (assume track is zero)
  if t==nil or s==nil or (t==0 and s==0) then return tslist end
  --do a little sanity check, check against the expected offset, should match total
  expectedtslistoffset = sectorcount*122
  foundtslistoffset=getdiskbyte(t,s,0x5)+getdiskbyte(t,s,0x6)*256
  dprint(debugstr,"expected tslist position="..expectedtslistoffset)
  dprint(debugstr,"found    tslist position="..foundtslistoffset)
  if expectedtslistoffset~=foundtslistoffset then 
     dprint(debugstr,"***EXPECTED TS DOESNT MATCH***") return nil 
  end
  sectorcount=sectorcount+1
  for i=0,121 do --this has to be 0 to 121 for 122 total pairs
    track=getdiskbyte(t,s,0xc+(0x2*i)) sector=getdiskbyte(t,s,0xc+(0x2*i)+1) 
    if track==nil or sector==nil then return tslist end
    if debugstr then print ("("..hex(t)..","..hex(s)..
                     ") entry="..hex(i).." count="..hex(total)..
                     " track,sector=("..hex(track)..","..hex(sector)..")") end
    if (track==0 and sector==0) then 
      if debugstr then print("0 for track no more entries") end 
      return tslist 
    else table.insert(tslist,{track,sector}) total=total+1 
    end  
    if total > 512 then print("TOTAL IS GREATER THAN 512") return tslist end  
  end   
  --get the next sector of the ts list
  dprint(debugstr,"GETTING NEXT TRACK SECTOR LIST")
  track=getdiskbyte(t,s,0x1) sector=getdiskbyte(t,s,0x2) t=track s=sector  dprint(debugstr,hexpair(t,s))
end 
end 


function getsector(track,sector) return string.sub(mydisk,(track*16+sector)*256+1,(track*16+sector)*256+1+256-1) end

function getfilefromtslist(tslist)local myfile="" for i,j in pairs(tslist) do  track=j[1] sector=j[2] remprint(hexpair(track,sector)) myfile=myfile..getsector(track,sector) end return myfile end

function hexdumpts(t,s) local str="" for i=0,255 do str=str..string.char(getdiskbyte(t,s,i)) end hexdump(str) end

function gettslocationfromcatalogname(a,debugstr)
local filelist,t,s
local t
local s
local nexttrack,nextsector,dostype
t = 17
s = 0
nexttrack=getdiskbyte(t,s,1)
nextsector=getdiskbyte(t,s,2)
dostype=getdiskbyte(t,s,3)
--print("CATALOG TRACK BEGINS "..hexpair(nexttrack,nextsector))
--print("DOSTYPE "..dostype)
  filelist,t,s=getcatalog(nexttrack,nextsector,a,true)
  return t,s
end

function getdos33file(a,debugstr)
  return stripfileheaderandextra(getfilefromtslist(gettslist(gettslocationfromcatalogname(a,debugstr))))
end

function getfile(a,debugstr)
  return getdos33file(a,debugstr)
end

function getdos33fileraw(a,debugstr)
return getfilefromtslist(gettslist(gettslocationfromcatalogname(a,debugstr)))
end

function getfileraw(a,debugstr)
  return getdos33fileraw(a,debugstr)
end


-- example: 5 % 16 = 5  so need to add 16 - 5 characters 
-- so it's add (multiple - (len % multiple))

function padtomultiple(a,multiple)
if a==nil then return 0
elseif (string.len(a) % multiple == 0) then return 0
else return multiple - (string.len(a) % multiple)
end
end

function padstringtomultipleof(a,multiple,padchar)
multiple = multiple or 16
padchar = padchar or " "
if a == nil then return nil end
return a .. string.rep(padchar,padtomultiple(a,multiple))
end

function hexdump(astr) 
local bytesperrow=16 
local bytecount=0 
local outstr="" 
for i=0,#astr-1+padtomultiple(astr,bytesperrow) do 
  if bytecount%bytesperrow == 0 then io.write(string.format("%02x",i).."   ") end 
  if i>string.len(astr)-1 then 
    getbyte=string.byte("_") io.write(string.format("%2s","__").." ") 
  else 
    getbyte=astr:byte(i+1) io.write(string.format("%02x",getbyte).." ") 
  end
  bytecount=bytecount + 1  
  if getbyte>128 then getbyte=getbyte-128 end 
  outstr=outstr..iif(getbyte>=32 and getbyte~=127,string.char(getbyte),".") 
  if bytecount % (bytesperrow/2) == 0 then io.write (" |  ") end 
  if bytecount % bytesperrow == 0 then io.write(""..outstr.."\n") outstr="" end
end 
end

function textdump(astr) 
local bytesperrow=80 
local bytecount=0 
local rowcount=0
local outstr="" 
for i=0,#astr-1+padtomultiple(astr,bytesperrow) do 
  if rowcount%bytesperrow == 0 then io.write(string.format("%02x",i).."   ") end 
  if i>string.len(astr)-1 then 
    getbyte=string.byte("_") 
    -- io.write(string.format("%2s","__").." ") 
  else 
    getbyte=astr:byte(i+1) 
    -- io.write(string.format("%02x",getbyte).." ") 
  end
  bytecount=bytecount + 1  
  rowcount=rowcount+1
  if getbyte>128 then getbyte=getbyte-128 end 
  outstr=outstr..iif(getbyte>=32 and getbyte~=127,string.char(getbyte),".") 
  --if bytecount % (bytesperrow/2) == 0 then io.write (" |  ") end 
  if rowcount % bytesperrow == 0 or getbyte==13 then io.write(""..outstr.."\n") rowcount=0 outstr="" end
end 
end

function loaddisk(filename)
local myfile
myfile=io.open(filename,"r") mydisk=assert(myfile:read("*a")) myfile:close()
end

function filetypetochar(a)
  if a==0 then return "T" 
  elseif (a&0x01)~=0 then return "I"
  elseif (a&0x02)~=0 then return "A"
  elseif (a&0x04)~=0 then return "B"
  elseif (a&0x08)~=0 then return "S"
  else return "X"
  end
end


function getnextcatalogsector(t,s)
-- if it gets nils, then start at VTOC at 17,0
t = t or 17
s = s or 0
nexttrack=getdiskbyte(t,s,1)
nextsector=getdiskbyte(t,s,2)
return nexttrack,nextsector
end


--all in one function, scan catalog, print catalog, 
-- stop when found a match, if matching nil do all, 
-- if "" then get first entry, 
-- return last ts for filelist if matched

function getcatalog(t,s,namewanted,printcatalog,debugstr)
local tslistt,tslists
local filelist={} 
local filetype,filesectors 
rem('namewanted=namewanted..string.rep(" ",30-#namewanted)') if debugstr then if not (namewanted==nil) then print ("#namewanted="..#namewanted) else print("namewanted is nil") end end
if debugstr then hexdumpts(t,s) end 
if t==nil then catt,cats=getnextcatalogsector(t,s)
else catt,cats=t,s
end

while catt~=0 and cats~=0 do  
  t,s=catt,cats if t>34 then print("T="..t.." out of range") break end 
  if debugstr then hexdumpts(t,s) end 
  for f=0,6 do 
    filetype=getdiskbyte(t,s,11+(0x23*f)+2) 
    locked=(filetype&0x80)~=0 
    filename="" 
    filesectors=getdisk2bytes(t,s,11+0x23*f+0x21)
    for g=0,29 do getbyte=getdiskbyte(t,s,11+(0x23*f)+3+g) 
      getbyte=getbyte&0x7f filename=filename..string.char(getbyte) end
      tslistt,tslists=getdiskbytepair(t,s,11+0x23*f+0x0)
      if filename~=string.rep(string.char(0),30) and tslistt~=0xFF then 
        table.insert(filelist,filename) 
      if printcatalog or debugstr then 
        print(hexpair(t,s).." "..hex(f).."  "..iif(locked,"*"," ")..
             filetypetochar(filetype&0x7F).." "..hex(filesectors,3).." "..
             filename.." TS List="..hexpair(getdiskbytepair(t,s,11+0x23*f+0x0))) 
      end 
    end
    if tslistt==0xFF then 
      table.insert(filelist,"<DELETED>"..filename) 
      if printcatalog or debugstr then 
        print(hexpair(t,s).." "..hex(f).."  "..iif(locked,"*"," ")..
              filetypetochar(filetype&0x7F).." "..hex(filesectors,3).." "..
              "<DELETED> "..filename.." TS List="..hexpair(getdiskbytepair(t,s,11+0x23*f+0x0))) 
      end 
    end
    -- you MUST have parentheses around namewanted==nil 
    if not (namewanted==nil) then 
    if debugstr then print(hexpair(t,s).." filename #"..f.."="..filename.."<<") hexdump(filename)  
                     print ("namewanted="..namewanted.."<<") hexdump(namewanted)
    end 
    if filename==namewanted or filename:sub(1,#namewanted)==namewanted then 
        print("matched \""..namewanted.."\" with \""..filename.."\"")
      if debugstr then print("MATCHED") end 
--      return filelist,getdiskbyte(t,s,11+0x23*f+0x0),getdiskbyte(t,s,11+0x23*f+0x1)
--      return filelist,getdiskbytepair(t,s,11+0x23*f+0x0)
      return filelist,tslistt,tslists
    end
    end
  end   
--  catt,cats=getdiskbytepair(t,s,1)
  catt,cats=getnextcatalogsector(t,s)
  if debugstr then print("Next TS="..hexpair(catt,cats)) end  
end  
--  return filelist,getdiskbytepair(t,s,11+0x23*f+0x0)
  return filelist,tslistt,tslists
end

function getcatalogfilelist()
local t
local s
local nexttrack,nextsector,dostype
t = 17
s = 0
nexttrack=getdiskbyte(t,s,1)
nextsector=getdiskbyte(t,s,2)
dostype=getdiskbyte(t,s,3)
--print("CATALOG TRACK BEGINS "..hexpair(nexttrack,nextsector))
--print("DOSTYPE "..dostype)
return getcatalog(nexttrack,nextsector)
end



function istslistsane(tslist)
if tslist == nil then return false end
-- checking if equal to {} doesn't work
-- if tslist == {} then return false end
if #tslist == 0 then return false end
for i,j in pairs(tslist) do
  if j[1]>34 then return false end
  if j[2]>15 then return false end
end
return true
end

-- learned a couple of lua things today
-- you can have an extra , in a table declaration and it doesn't change the table
-- print(#{1,2,})
-- 2


function revtablekeysvalues(a)
local b={}
for i,j in pairs(a) do b[j]=i end
return b
end



function printt_number(a)
  if a==nil then return end
-- math.tointeger(a) will return nil or the number
  if math.tointeger(a) then
-- I find it useful to print the numbers as both hex and decimal
    io.write(string.format("0x%x",a).." "..string.format("%d",a))
--    io.write(string.format("0x%x",a))
  else
-- must be a floating point
    io.write(string.format("6.2%f",a))
    -- could also just io.write(a)
  end
end


function printt(a,level,itemsperrow,shownumindex,printreturnatend) 
-- okay, here we recurse, but check to see if it's a table first
-- oops if you have local in front it supersedes the incoming parameter
-- param or nil idiom does not work for incoming boolean values
-- printreturnatend=printreturnatend or true
if printreturnatend == nil then printreturnatend = true end
--shownumindex=shownumindex or false
if shownumindex == nil then shownumindex = false end
--error: diskimage_file_lua4_clean.txt:325: attempt to perform 'n%0' because itemsperrow was zero
--local itemsperrow=itemsperrow or 1
if itemsperrow==nil then itemsperrow = 1 end
if itemsperrow<1 then itemsperrow = 1 
--print("WHY IS ITEMSPERROW ZERO") 
end
--itemsperrow=itemsperrow or 1
--print("ITEMSPERROW="..itemsperrow)
level = level or 1
if level<1 then level=1 end
if a==nil then return end 
local itemcount=1
if type(a)=="table" then 
   io.write("{") 
   for i,j in pairs(a) do 
      if itemcount>1 then io.write(", ") end
 --     print("ITEMSPERROW="..itemsperrow)
      if (itemcount>1) and (((itemcount-1) % itemsperrow) == 0) then io.write("\n") end
--io.write(i.."=")
      if type(j)=="table" then if shownumindex then io.write(i.." = ") end
if type(i)=="string" then io.write("\""..i.."\" = ") end
 printt(j,level+1,12,shownumindex,printreturnatend) else 
         if type(i)=="string" then io.write("\""..i.."\" = ") else 
          if shownumindex then io.write(i.." = ") end end printt(j,level+1,12,shownumindex,printreturnatend) end
      itemcount=itemcount+1
   end 
   io.write("}") if level==1 then io.write("\n") end
--else io.write(a) end 
else if type(a)=="string" then io.write("\""..a.."\"") elseif type(a)=="number" then printt_number(a) else io.write(tostring(a)) end end   -- needed because write doesnt autoconvert to string like print
if level==1 then if printreturnatend then io.write("\n") end end
end



function bloadstring(a,addr) 
addr = addr or 0x2000
local cpu = manager:machine().devices[":maincpu"] 
local mem = cpu.spaces["program"]
local apos=1
if a==nil then return end
if #a==0 then return end
for i=addr,addr+#a-1 do mem:write_u8(i,a:byte(apos)) apos=apos+1 end
end

function bloaddos33file(name,newaddr,dasmname,execute_bool)
local a
local b
local cpu = manager:machine().devices[":maincpu"] 
local mem = cpu.spaces["program"]
  a=getdos33fileraw(name)
  a,aaddr,alength = stripfileheaderandextra(a)
  if newaddr then aaddr = newaddr end
  for i=1,#a do
    mem:write_u8(aaddr+i-1,a:byte(i))
  end
if not(dasmname == nil) then
--print(manager:machine().devices[":maincpu"]:debug())
--sol.device_debug*: 0x5590ea194e28
--print(manager:machine():debugger())
--sol.debugger_manager*: 0x5590ea194ee8
--  print(manager:machine():debugger():command("help dasm"))
-- dasm <filename>,<address>,<length>[,<opcodes>[,<CPU>]]
   manager:machine():debugger():command("dasm ".."\"DASM_OUTPUT_FILE_"..dasmname.."\","..hex(aaddr)..","..hex(alength))
-- debugger makes the filename lower case unless you use quotes

end
  if execute_bool then
   print("pc="..hex(aaddr))
   manager:machine():debugger():command("pc="..hex(aaddr))
   print("g")
   manager:machine():debugger():command("g")
  end
end

function bload(name,newaddr,dasmname,execute_bool)
  bloaddos33file(name,newaddr,dasmname,execute_bool)
end

function stop()
   manager:machine():debugger():command("s")
end
function step()
   manager:machine():debugger():command("s")
end

function readswitch(a)
local cpu = manager:machine().devices[":maincpu"]  local mem = cpu.spaces["program"]
mem:read_u8(a)
end


function hgrfull(page)
page = page or 1
readswitch(0xC050) -- graphics
readswitch(0xC052) -- full screen
readswitch(0xC054+page-1) -- page 1
readswitch(0xC057) -- hi res
end

function hgr(page)
page = page or 1
readswitch(0xC050) -- graphics
readswitch(0xC053) -- full mixed
readswitch(0xC054+page-1) -- page 1
readswitch(0xC057) -- hi res
end

function textmode()
readswitch(0xC051) -- text
readswitch(0xC054) -- page 1
end

function text()
readswitch(0xC051) -- text
readswitch(0xC054) -- page 1
end

  

function scandiskforsanetslist(debugstr)
for t=0,34 do for s=0,15 do dprint(debugstr,"TRACK="..t.."  SECTOR= "..s) if istslistsane(gettslist(t,s)) then print("TRACK="..t.."  SECTOR= "..s) dprint(debugstr,"SANE TSLIST"..string.rep("=",80)) 
printt(gettslist(t,s)) 
--printt2(gettslist(t,s)) tsl=gettslist(t,s) 
end end end
end


function catalog()
return getcatalog(nil,nil,nil,true)
end


function makeapplesofttokentable()
applesofttokentable={
[128]="END",
[129]="FOR",
[130]="NEXT",
[131]="DATA",
[132]="INPUT",
[133]="DEL",
[134]="DIM",
[135]="READ",
[136]="GR",
[137]="TEXT",
[138]="PR #",
[139]="IN #",
[140]="CALL",
[141]="PLOT",
[142]="HLIN",
[143]="VLIN",
[144]="HGR2",
[145]="HGR",
[146]="HCOLOR=",
[147]="HPLOT",
[148]="DRAW",
[149]="XDRAW",
[150]="HTAB",
[151]="HOME",
[152]="ROT=",
[153]="SCALE=",
[154]="SHLOAD",
[155]="TRACE",
[156]="NOTRACE",
[157]="NORMAL",
[158]="INVERSE",
[159]="FLASH",
[160]="COLOR=",
[161]="POP",
[162]="VTAB",
[163]="HIMEM:",
[164]="LOMEM:",
[165]="ONERR",
[166]="RESUME",
[167]="RECALL",
[168]="STORE",
[169]="SPEED=",
[170]="LET",
[171]="GOTO",
[172]="RUN",
[173]="IF",
[174]="RESTORE",
[175]="&",
[176]="GOSUB",
[177]="RETURN",
[178]="REM",
[179]="STOP",
[180]="ON",
[181]="WAIT",
[182]="LOAD",
[183]="SAVE",
[184]="DEF FN",
[185]="POKE",
[186]="PRINT",
[187]="CONT",
[188]="LIST",
[189]="CLEAR",
[190]="GET",
[191]="NEW",
[192]="TAB",
[193]="TO",
[194]="FN",
[195]="SPC(",
[196]="THEN",
[197]="AT",
[198]="NOT",
[199]="STEP",
[200]="+",
[201]="-",
[202]="*",
[203]="/",
[204]=";",
[205]="AND",
[206]="OR",
[207]=">",
[208]="=",
[209]="<",
[210]="SGN",
[211]="INT",
[212]="ABS",
[213]="USR",
[214]="FRE",
[215]="SCRN (",
[216]="PDL",
[217]="POS",
[218]="SQR",
[219]="RND",
[220]="LOG",
[221]="EXP",
[222]="COS",
[223]="SIN",
[224]="TAN",
[225]="ATN",
[226]="PEEK",
[227]="LEN",
[228]="STR$",
[229]="VAL",
[230]="ASC",
[231]="CHR$",
[232]="LEFT$",
[233]="RIGHT$",
[234]="MID$",
[235]="",
[236]="",
[237]="",
[238]="",
[239]="",
[240]="",
[241]="",
[242]="",
[243]="",
[244]="",
[245]="",
[246]="",
[247]="",
[248]="",
[249]="",
[250]="",
[251]="",
[252]="",
[253]="",
[254]="",
[255]="",
}
for i=32,127 do applesofttokentable[i]=string.char(i) end
for i=1,31 do applesofttokentable[i]="<CONTROL+"..string.char(i+64)..">" end
applesofttokentable[0]="<NUL>"
end


function basdump(a,showctrlchars,len)
if len==nil then len=string.byte(a,1)+string.byte(a,2)*256 end -- get the length of the file 
pos=1
pos=pos+4  -- skip 2 bytes (length of file) and skip 2 byte address of the next line
while true do
if pos > len then print("DONE") return end
if pos > #a then print("DONE") return end
-- first 2 bytes are the pointer to the next line
-- next 2 bytes are the line number
linenum = a:byte(pos)+a:byte(pos+1)*256
--print("LINE="..linenum,pos)
io.write(linenum.."  ")
pos=pos+2
while true do
if a:byte(pos)>=128 then io.write(" "..applesofttokentable[a:byte(pos)].." ") pos=pos+1 
elseif a:byte(pos)==0 then print() pos = pos + 1 break 
elseif a:byte(pos)<128 then if showctrlchars then io.write(applesofttokentable[a:byte(pos)]) else io.write((a:sub(pos,pos))) end pos=pos+1
end
end
pos=pos+2  -- skip the 2 byte address of the next line
end
end

function basdumpraw(a)
  basdump(string.rep(string.char(0),4)..a,true,a:len()+4)
end

makeapplesofttokentable()

--some examples:
--myfile=io.open("stellar7.dsk","r") mydisk=assert(myfile:read("*a")) myfile:close()
--catalog()
--catalog("hexdump")
--a=getfilefromtslist(gettslist(0x21,0x05))
-- a=getfileraw("HELLO")
-- a=getfileraw("LEVELS")
-- basdump(a)
--   show the basic file
-- basdump(a,true)
--   show the basic file with control chracters
-- hexdump(a)
-- a=getfileraw("LETTER")
-- textdump(a)
-- bload("BRIEF",0x2000)
-- hgr()
