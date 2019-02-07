INCLUDE \masm32\include\masm32rt.inc
INCLUDE \masm32\include\Irvine32.inc
INCLUDELIB \masm32\lib\Irvine32.lib
INCLUDE \masm32\include\debug.inc
INCLUDELIB \masm32\lib\debug.lib

tile STRUCT
;orientation - 0=covered, 1 = flagged, 2 = flipped
;tileType - ranges from 0-9, represents bombs it touches, 9 = bomb
    orientation BYTE 0
    tileType BYTE 0
tile ENDS

coord STRUCT
    X BYTE 0
    Y BYTE 0
coord ENDS


DisplayGrid PROTO, aArr:DWORD, tblWidth:BYTE, tblHeight:BYTE
DepositBombs PROTO, aArr:DWORD, tblWidth:BYTE, tblHeight:BYTE, amtBombs:BYTE

GiveTypes PROTO, aArr:DWORD, tblWidth:BYTE, tblHeight:BYTE

CheckUpper PROTO, aArr:DWORD, tblWidth:BYTE
CheckLower PROTO, aArr:DWORD, tblWidth:BYTE, tblHeight:BYTE

MoveCursor PROTO, thePoint:DWORD, tblWidth:BYTE, tblHeight:BYTE

ModifyType PROTO, aArr:DWORD, thePoint:DWORD, tblWidth:BYTE, tblHeight:BYTE

UncoverZeros PROTO, aArr:DWORD, tblWidth:BYTE, tblHeight:BYTE, rowPos:BYTE, colPos:BYTE, currPos:DWORD


.data   
    currPoint coord <0,0>

    instructions BYTE "Use w, a, s, d to move, f to flag tile, r to reveal tile", 0
    gameLose BYTE "You found a bomb, you lose", 0
    gameWin BYTE "You win!", 0
    difficulty BYTE "Enter: (e)asy, (m)edium, or (h)ard", 0

    startTime DWORD ?
    tableWidth BYTE 9
    tableHeight BYTE 9
    bombs BYTE 10
    Table tile 30 DUP(16 DUP(<0,0>))
   
.code
  main PROC
    mov edx, OFFSET difficulty
    Call WriteString
    Call ReadChar
    OR al, 20h

    cmp al, 'e'
    JE startGame
    cmp al, 'm'
    JE medium

    mov tableWidth, 30
    mov tableHeight, 16
    mov bombs, 99

    jmp startGame
    medium:
    mov tableWidth, 16
    mov tableHeight, 16
    mov bombs, 40
   
    startGame:
    mov eax, 0
    mov ecx, LENGTHOF difficulty
    mov edx, 0
    clearText:
        Call Gotoxy
        push edx
        mov edx, ' '
        Call WriteChar
        pop edx
        inc dl   
    loop clearText

    ;Call WriteDec
    ;Call Crlf
    ;Call GetMseconds
    ;Call WriteDec
    ;Call Crlf
    ;inkey

    INVOKE DepositBombs, ADDR Table, tableWidth, tableHeight, bombs
   

    INVOKE GiveTypes, ADDR Table, tableWidth, tableHeight

    mov currPoint.X, 0
    mov currPoint.Y, 0
    INVOKE MoveCursor, ADDR currPoint, tableWidth, tableHeight

    INVOKE DisplayGrid, ADDR Table, tableWidth, tableHeight
    mov edx, OFFSET instructions
    Call WriteString
    
    INVOKE MoveCursor, ADDR currPoint, tableWidth, tableHeight

    
    ;DumpMem OFFSET Table, LENGTHOF Table * TYPE Table, "Board"
    mov eax, 0
    mov edx, 0
    
    mov ebx, 0
    mov esi, OFFSET Table
    gameLoop:  
        Call ReadChar
        mov bl, al 
        mov eax, 0
      
        INVOKE MoveCursor, ADDR currPoint, tableWidth, tableHeight
        INVOKE ModifyType, ADDR Table, ADDR currPoint, tableWidth, tableHeight

        mov esi, OFFSET Table
        movsx eax, tableWidth
        mul tableHeight
        mov ecx, eax
        mov eax, 0
        mov ebx, 0
        push edx
        push esi
        checkLoop:
            mov dl, [esi]
            inc esi
            mov dh, [esi]
            
            ;checks if bomb is flipped or all bombs flagged
            cmp dh, 9
            JNE revealCheck
            cmp dl, 2
            JE lose
            cmp dl, 1
            JNE revealCheck
            inc ebx
     

            revealCheck:
            cmp dl, 2
            JNE fakeCheck
            inc eax

            fakeCheck:


            contCheckLoop:

            inc esi
        loop checkLoop
        
        movsx edx, bombs
        cmp ebx, edx
        JE win

        push eax
        movsx eax, tableWidth
        mul tableHeight
        mov ebx, eax
        pop eax
        
        sub ebx, edx
        
        cmp ebx, eax
        JE win

        pop esi
        pop edx
    jmp gameLoop

        lose:
        mov dl, 0
        mov dh, tableHeight
        inc dh
        Call Gotoxy
        mov edx, OFFSET gameLose
        Call WriteString
        Call Crlf

        
        jmp endGame

        win:
        mov dl, 0
        mov dh, tableHeight
        inc dh
        Call Gotoxy
        mov edx, OFFSET gameWin
        Call WriteString
        Call Crlf

        endGame:
        pop esi
        pop edx
        
   ;mov ebx, 0
   ;mov edx, 0
   
    inkey
  INVOKE ExitProcess, 0
main ENDP

MoveCursor PROC USES eax ebx ecx edx esi, thePoint:DWORD, tblWidth:BYTE, tblHeight:BYTE

mov esi, thePoint

mov eax, 0
mov dl, [esi]
;inc esi
mov dh, [esi+1]
;bl contains direction, dl contains x, dh contians y
 
    cmp bl, 's'
    JNE checkUP
    inc dh
    cmp dh, tblHeight
    JNE movCurs
    mov dh, 0
    jmp movCurs
      
    checkUP:
    cmp bl, 'w'
    JNE checkLeft
    dec dh
    cmp dh, -1
    JNE movCurs
    mov dh, tblHeight
    dec dh
    jmp movCurs

    checkLeft:
    cmp bl, 'a'
    JNE checkRight
    dec dl
    cmp dl, -1
    JNE movCurs
    mov dl, tblWidth
    dec dl
    jmp movCurs

    checkRight:
    cmp bl, 'd'
    JNE movCurs
    inc dl
    cmp dl, tblWidth
    JNE movCurs
    mov dl, 0

    movCurs:

    Call Gotoxy

    mov [esi+1], dh
    mov [esi], dl

ret
MoveCursor ENDP

ModifyType PROC USES eax ebx ecx edx edi, aArr:DWORD, thePoint:DWORD, tblWidth:BYTE, tblHeight:BYTE
.data
    posInArray DWORD ?
    rowSpot BYTE ?
    colSpot BYTE ?
.code

mov ecx, thePoint

        mov al, 'r'
        cmp al, bl
        JNE checkFlags
        mov bl, 2
        jmp theMath

        checkFlags:
        mov al, 'f'
        cmp al, bl
        JNE contLoop
        mov bl, 1

        theMath:
        
        mov eax, 0
        mov al, [ecx]
        mov edi, 2
        mul edi
        push eax

        mov al, [ecx+1]
        mul edi
        movsx edi, tblWidth
        mul edi
        mov edi, eax
        pop eax
        add eax, edi
        mov edx, eax

        mov eax, 0
        mov al, BYTE PTR [esi+edx]

        ;orientation - 0=covered, 1 = flagged, 2 = flipped
        ;if al is 0 and bl is 1 or 2, allow
        ;if al is 1 and bl is 2 then 0
        ;if al is 2 and bl is 1 then skip

        cmp al, 1
        JNE finalCheck
        cmp bl, 2
        JNE finalCheck
        mov bl, 0
        jmp checkZeros

        finalCheck:
        cmp al, 2
        JNE checkZeros
        cmp bl, 1
        JE contLoop
        
        checkZeros:
        mov eax, 0
        mov al, BYTE PTR [esi+edx+1]
        cmp al, 0
        JNE movCurs

        mov posInArray, 0
        mov eax, 0
        mov al, [ecx]
        mov ah, [ecx+1]
        mov colSpot, ah
        inc colSpot
        mov rowSpot, al
        inc rowSpot
        mov posInArray, edx
        inc posInArray 
        
        INVOKE UncoverZeros, aArr, tblWidth, tblHeight, rowSpot, colSpot, posInArray

        movCurs:

        mov BYTE PTR [esi+edx], bl
     
        push edx
        mov edx, 0
        mov dl, 0
        mov dh, 0
        Call Gotoxy
        pop edx

        INVOKE DisplayGrid, aArr, tblWidth, tblHeight
        INVOKE MoveCursor, thePoint, tblWidth, tblHeight

        contLoop:

ret
ModifyType ENDP

DisplayGrid PROC USES eax ebx ecx edx edi esi, aArr:DWORD, tblWidth:BYTE, tblHeight:BYTE
    movsx eax, tblWidth
    mul tblHeight
    
    mov ecx, eax   
    mov esi, aArr
    
    mov ebx, 0
    mov eax, 0

    DisplayStuff:
        
        mov al, [esi]
        add esi, 1
        ;orientation - 0=covered, 1 = flagged, 2 = flipped
        mov dl, 0
        cmp dl, al
        JE displayBox
        inc dl
        cmp dl, al
        JE displayFlag   

        displayNum:
            mov al, [esi]
            cmp al, 9
            JE displayBomb
            Call WriteDec
            jmp checkForSpace
            displayBomb:
            mov al, '*'
            Call WriteChar
            jmp checkForSpace

        displayFlag:
            mov al, 'F'
            Call WriteChar
            jmp checkForSpace

        displayBox:
            mov al, 'X'
            Call WriteChar
            jmp checkForSpace             

        checkForSpace:
            add esi, 1
            inc ebx
            movsx edx, tblWidth
            cmp edx, ebx
            JG contLoop2
                mov ebx, 0
                Call Crlf
            contLoop2:

    loop DisplayStuff
ret
DisplayGrid ENDP

DepositBombs PROC USES eax ebx ecx edx esi edi, aArr:DWORD, tblWidth:BYTE, tblHeight:BYTE, amtBombs:BYTE


movsx eax, tblWidth
mul tblHeight
;edi contains max
mov ebx, 2
mul ebx
mov edi, eax

;eax, ebx, ecx, edx, esi, edi
;tak, 
movsx ecx, amtBombs
mov esi, aArr

Call Randomize
placeBombs:
    mov eax, edi

    Call RandomRange
    
    cmp eax, 0
    JNE checkEven
    inc eax
         
    checkEven:
        mov ebx, eax
        mov edx, 0
        push ecx
        mov ecx, 2
        div ecx
        pop ecx

    cmp edx, 0
    JNE addBomb
    inc ebx

    addBomb:
        mov al, 9
        cmp [esi+ebx], al
        JE placeBombs
        mov [esi+ebx], al

loop placeBombs


ret
DepositBombs ENDP

UncoverZeros PROC USES eax ebx ecx edx edi esi, aArr:DWORD, tblWidth:BYTE, tblHeight:BYTE, rowPos:BYTE, colPos:BYTE, currPos:DWORD


mov esi, aArr
mov edi, currPos


movsx eax, tblWidth
mov ebx, 2
mul ebx
mov edx, eax
mov eax, 0

;orientation - 0=covered, 1 = flagged, 2 = flipped

;checks up for any zeros
push edi
sub edi, edx
cmp edi, 0
JL checkDown
mov al, [esi+edi-1]
cmp al, 2
JE checkDown
mov al, [esi+edi]
cmp al, 0
JNE checkDown
mov ebx, 0
mov bh, 2
mov [esi+edi-1], bh
mov currPos, edi
INVOKE UncoverZeros, aArr, tblWidth, tblHeight, rowPos, colSpot, currPos


;checks down for any zeros
checkDown:
pop edi

push edi
add edi, edx
cmp edi, 0
JL checkLeft
;Call DumpRegs
mov al, [esi+edi-1]
cmp al, 2
JE checkLeft
mov al, [esi+edi]
cmp al, 0
JNE checkLeft
mov ebx, 0
mov bh, 2
mov [esi+edi-1], bh
mov currPos, edi
INVOKE UncoverZeros, aArr, tblWidth, tblHeight, rowPos, colSpot, currPos


;check left
checkLeft:
pop edi

push edi
movsx ecx, rowPos
dec ecx
cmp ecx, 0
JE checkRight
mov al, [esi+edi-3]
cmp al, 2
JE checkRight
mov al, [esi+edi-2]
cmp al, 0
JNE checkRight
mov bh, 2
mov [esi+edi-3], bh
sub edi, 2
mov currPos, edi
dec rowPos
INVOKE UncoverZeros, aArr, tblWidth, tblHeight, rowPos, colSpot, currPos


;check right
checkRight:
pop edi

movsx ecx, rowPos
inc ecx
movsx edx, tblWidth
cmp ecx, edx
JG breakOut
mov al, [esi+edi+1]
cmp al, 2
JE breakOut
mov al, [esi+edi+2]
cmp al, 0
JNE breakOut
mov bh, 2
mov [esi+edi+1], bh
add edi, 2
mov currPos, edi
inc rowPos
INVOKE UncoverZeros, aArr, tblWidth, tblHeight, rowPos, colSpot, currPos


breakOut:


ret
UncoverZeros ENDP

GiveTypes PROC USES ecx, aArr:DWORD, tblWidth:BYTE, tblHeight:BYTE

movsx eax, tblWidth
movsx ebx, tblHeight
mul ebx
mov ebx, 0
mov ecx, eax
movsx eax, tblWidth

mov edx, 0
mov dl, 9d
mov dh, 2d
mov esi, aArr

mul dh
mov edi, eax
inc edi
mov eax, aArr

placeTypes:
    ;if tile isnt bomb then continue
    cmp [esi+1], dl
    JNE contLoop

    push ecx
    push edi
    push esi
    INVOKE CheckUpper, aArr, tblWidth
    pop esi
    pop edi
   
    push edi
    push esi
    INVOKE CheckLower, aArr, tblWidth, tblHeight
    pop esi
    pop edi

    push esi
    dec esi

    cmp esi, aArr
    JL checkBehind
    cmp [esi], dl
    JE checkBehind
    mov ecx, 0
    cmp ebx, ecx
    JE checkBehind
    inc BYTE PTR [esi]
    
    checkBehind:
    add esi, 4
    cmp [esi], dl
    JE contThis
    movsx ecx, tblWidth
    dec ecx
    cmp ecx, ebx
    JE contThis
    inc BYTE PTR [esi]
    contThis:

    pop esi
    
    pop ecx
    contLoop:
    add esi, 2
    push esi
    
    inc ebx
    movsx esi, tblWidth
    cmp esi, ebx
    JG contLoop2
    mov ebx, 0
    
    contLoop2:

    pop esi

loop placeTypes


ret
GiveTypes ENDP

CheckLower PROC USES ecx edi esi eax edx ebx, aArr:DWORD, tblWidth:BYTE, tblHeight:BYTE


    sub edi, 2

    movsx ecx, tblWidth
    dec ecx
       
    cmp ecx, ebx
    JE lowerEcx
    mov ecx, 3
    jmp contChecks

    lowerEcx:
    mov ecx, 2

    contChecks:
    push eax
    push ebx
    mov eax, 0

    cmp eax, ebx
    JNE doneChecks
    add edi, 2
    mov ecx, 2 
    
    doneChecks:
    pop ebx
    pop eax

    loopLower:

        push esi
        
        add esi, edi
        mov eax, aArr
       
        cmp [esi], dl
        JE contLower
        inc BYTE PTR [esi]

        contLower:
        
        pop esi
        add edi, 2
    loop loopLower

 
 ret
 CheckLower ENDP

CheckUpper PROC USES ecx edi esi eax edx ebx, aArr:DWORD, tblWidth:BYTE

 
    movsx ecx, tblWidth
    dec ecx
    cmp ecx, ebx
    JE lowerEcx
    mov ecx, 3
    jmp contChecks

    lowerEcx:
    mov ecx, 2

    contChecks:
    push eax
    push ebx
    mov eax, 0

    cmp eax, ebx
    JNE doneChecks
    sub edi, 2
    mov ecx, 2
    
    doneChecks:
    pop ebx
    pop eax
    
    loopUpper:
        push esi
        
        sub esi, edi
        mov eax, aArr
       
        cmp esi, eax
        JL contUpper

        cmp [esi], dl
        JE contUpper
        inc BYTE PTR [esi]     

        contUpper:
        pop esi
        sub edi, 2

    loop loopUpper


ret
CheckUpper ENDP

END main
