--[[
	Roblox Chess Game - HTTP Loader
	Host this on GitHub Raw / Pastebin and run:
	loadstring(game:HttpGet("URL"))()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local isServer = RunService:IsServer()
local isClient = RunService:IsClient()

if not isServer and not isClient then
	return warn("Unknown context - must run inside Roblox")
end

--===========================================================
-- SOURCE CODE for each module/script
--===========================================================

local PieceDataSource = [[
local PieceData = {}
PieceData.Pieces = {
	White = { Pawn = "wP", Knight = "wN", Bishop = "wB", Rook = "wR", Queen = "wQ", King = "wK" },
	Black = { Pawn = "bP", Knight = "bN", Bishop = "bB", Rook = "bR", Queen = "bQ", King = "bK" }
}
PieceData.PieceValues = {
	wP = 100, wN = 320, wB = 330, wR = 500, wQ = 900, wK = 20000,
	bP = 100, bN = 320, bB = 330, bR = 500, bQ = 900, bK = 20000
}
PieceData.PieceSymbols = {
	wP = "♙", wN = "♘", wB = "♗", wR = "♖", wQ = "♕", wK = "♔",
	bP = "♟", bN = "♞", bB = "♝", bR = "♜", bQ = "♛", bK = "♚"
}
function PieceData.GetColor(p) if not p then return nil end return p:sub(1,1)=="w" and "White" or "Black" end
function PieceData.IsWhite(p) return p and p:sub(1,1)=="w" end
function PieceData.IsBlack(p) return p and p:sub(1,1)=="b" end
function PieceData.IsColor(p,c) if not p then return false end return (c=="White" and PieceData.IsWhite(p)) or (c=="Black" and PieceData.IsBlack(p)) end
return PieceData
]]

local ChessLogicSource = [[
local PieceData = require(script.Parent.PieceData)
local ChessLogic = {}
ChessLogic.BoardSize = 8
function ChessLogic.NewBoard()
	local b={} for x=1,8 do b[x]={} for y=1,8 do b[x][y]=nil end end
	local r={"R","N","B","Q","K","B","N","R"}
	for x=1,8 do b[x][1]="w"..r[x];b[x][2]="wP";b[x][7]="bP";b[x][8]="b"..r[x] end
	return b
end
function ChessLogic.CloneBoard(b) local c={} for x=1,8 do c[x]={} for y=1,8 do c[x][y]=b[x][y] end end return c end
function ChessLogic.InBounds(x,y) return x>=1 and x<=8 and y>=1 and y<=8 end
function ChessLogic.IsValidPawnMove(b,fx,fy,tx,ty,c,ep)
	local d=c=="White" and 1 or -1; local sr=c=="White" and 2 or 7
	if tx==fx and ty==fy+d and not b[tx][ty] then return true end
	if tx==fx and ty==fy+2*d and fy==sr then local my=fy+d; if not b[tx][ty] and not b[tx][my] then return true end end
	if math.abs(tx-fx)==1 and ty==fy+d then
		if b[tx][ty] and PieceData.IsColor(b[tx][ty],c=="White" and "Black" or "White") then return true end
		if ep and tx==ep.x and ty==ep.y then return true end
	end
	return false
end
function ChessLogic.IsValidKnightMove(b,fx,fy,tx,ty,c) local dx,dy=math.abs(tx-fx),math.abs(ty-fy) if not((dx==2 and dy==1)or(dx==1 and dy==2)) then return false end local t=b[tx][ty] if t and PieceData.IsColor(t,c) then return false end return true end
function ChessLogic.IsValidBishopMove(b,fx,fy,tx,ty,c)
	if math.abs(tx-fx)~=math.abs(ty-fy) then return false end
	local sx,sy=tx>fx and 1 or -1,ty>fy and 1 or -1; local x,y=fx+sx,fy+sy
	while x~=tx or y~=ty do if b[x][y] then return false end x=x+sx;y=y+sy end
	local t=b[tx][ty]; if t and PieceData.IsColor(t,c) then return false end; return true
end
function ChessLogic.IsValidRookMove(b,fx,fy,tx,ty,c)
	if fx~=tx and fy~=ty then return false end
	if fx==tx then local sy=ty>fy and 1 or -1; local y=fy+sy while y~=ty do if b[fx][y] then return false end y=y+sy end
	else local sx=tx>fx and 1 or -1; local x=fx+sx while x~=tx do if b[x][fy] then return false end x=x+sx end end
	local t=b[tx][ty]; if t and PieceData.IsColor(t,c) then return false end; return true
end
function ChessLogic.IsValidQueenMove(b,fx,fy,tx,ty,c) return ChessLogic.IsValidBishopMove(b,fx,fy,tx,ty,c) or ChessLogic.IsValidRookMove(b,fx,fy,tx,ty,c) end
function ChessLogic.IsValidKingMove(b,fx,fy,tx,ty,c)
	local dx,dy=math.abs(tx-fx),math.abs(ty-fy)
	if dx<=1 and dy<=1 and dx+dy>0 then local t=b[tx][ty] if t and PieceData.IsColor(t,c) then return false end return true end
	if dx==2 and dy==0 then
		local row=fy; local e=c=="White" and "Black" or "White"
		if tx==7 then
			if b[8][row]==(c=="White" and "wR" or "bR") and not b[6][row] and not b[7][row] then
				if not ChessLogic.IsSquareAttacked(b,fx,fy,e) and not ChessLogic.IsSquareAttacked(b,fx+1,fy,e) and not ChessLogic.IsSquareAttacked(b,fx+2,fy,e) then return true,"kingside" end
			end
		elseif tx==3 then
			if b[1][row]==(c=="White" and "wR" or "bR") and not b[2][row] and not b[3][row] and not b[4][row] then
				if not ChessLogic.IsSquareAttacked(b,fx,fy,e) and not ChessLogic.IsSquareAttacked(b,fx-1,fy,e) and not ChessLogic.IsSquareAttacked(b,fx-2,fy,e) then return true,"queenside" end
			end
		end
	end
	return false
end
function ChessLogic.IsValidMove(b,fx,fy,tx,ty,c,cr,ep)
	if not ChessLogic.InBounds(fx,fy) or not ChessLogic.InBounds(tx,ty) then return false end
	local p=b[fx][fy] if not p or not PieceData.IsColor(p,c) then return false end
	local pt=p:sub(2,2); local v,ex=false,nil
	if pt=="P" then v=ChessLogic.IsValidPawnMove(b,fx,fy,tx,ty,c,ep)
	elseif pt=="N" then v=ChessLogic.IsValidKnightMove(b,fx,fy,tx,ty,c)
	elseif pt=="B" then v=ChessLogic.IsValidBishopMove(b,fx,fy,tx,ty,c)
	elseif pt=="R" then v=ChessLogic.IsValidRookMove(b,fx,fy,tx,ty,c)
	elseif pt=="Q" then v=ChessLogic.IsValidQueenMove(b,fx,fy,tx,ty,c)
	elseif pt=="K" then local s,e=ChessLogic.IsValidKingMove(b,fx,fy,tx,ty,c);v=s;ex=e end
	if not v then return false end
	local t=ChessLogic.CloneBoard(b); t[tx][ty]=t[fx][fy]; t[fx][fy]=nil
	if ex=="kingside" then t[tx-1][ty]=t[tx+1][ty];t[tx+1][ty]=nil
	elseif ex=="queenside" then t[tx+1][ty]=t[tx-2][ty];t[tx-2][ty]=nil end
	if ChessLogic.IsInCheck(t,c) then return false end; return true,ex
end
function ChessLogic.FindKing(b,c) local k=c=="White" and "wK" or "bK" for x=1,8 do for y=1,8 do if b[x][y]==k then return x,y end end end return nil,nil end
function ChessLogic.IsSquareAttacked(b,tx,ty,by)
	for x=1,8 do for y=1,8 do
		local p=b[x][y] if p and PieceData.IsColor(p,by) then
			local pt=p:sub(2,2)
			if pt=="P" then local d=by=="White" and 1 or -1 if math.abs(tx-x)==1 and ty==y+d then return true end
			elseif pt=="N" then local dx,dy=math.abs(tx-x),math.abs(ty-y) if(dx==2 and dy==1)or(dx==1 and dy==2)then return true end
			elseif pt=="B" then if math.abs(tx-x)==math.abs(ty-y) and tx~=x then local sx,sy=tx>x and 1 or -1,ty>y and 1 or -1;local cx,cy=x+sx,y+sy;local bl=false while cx~=tx or cy~=ty do if b[cx][cy]then bl=true;break end cx=cx+sx;cy=cy+sy end if not bl then return true end end
			elseif pt=="R" then if x==tx or y==ty then if x==tx and y~=ty then local s=ty>y and 1 or -1;local cy=y+s;local bl=false while cy~=ty do if b[x][cy]then bl=true;break end cy=cy+s end if not bl then return true end elseif y==ty then local s=tx>x and 1 or -1;local cx=x+s;local bl=false while cx~=tx do if b[cx][y]then bl=true;break end cx=cx+s end if not bl then return true end end end
			elseif pt=="Q" then if math.abs(tx-x)==math.abs(ty-y)or tx==x or ty==y then if math.abs(tx-x)==math.abs(ty-y)then local sx,sy=tx>x and 1 or -1,ty>y and 1 or -1;local cx,cy=x+sx,y+sy;local bl=false while cx~=tx or cy~=ty do if b[cx][cy]then bl=true;break end cx=cx+sx;cy=cy+sy end if not bl then return true end elseif x==tx then local s=ty>y and 1 or -1;local cy=y+s;local bl=false while cy~=ty do if b[x][cy]then bl=true;break end cy=cy+s end if not bl then return true end elseif y==ty then local s=tx>x and 1 or -1;local cx=x+s;local bl=false while cx~=tx do if b[cx][y]then bl=true;break end cx=cx+s end if not bl then return true end end end
			elseif pt=="K" then local dx,dy=math.abs(tx-x),math.abs(ty-y) if dx<=1 and dy<=1 and dx+dy>0 then return true end
			end
		end
	end end
	return false
end
function ChessLogic.IsInCheck(b,c) local kx,ky=ChessLogic.FindKing(b,c) if not kx then return false end local e=c=="White" and "Black" or "White" return ChessLogic.IsSquareAttacked(b,kx,ky,e) end
function ChessLogic.HasLegalMoves(b,c) for x=1,8 do for y=1,8 do local p=b[x][y] if p and PieceData.IsColor(p,c) then for tx=1,8 do for ty=1,8 do if x~=tx or y~=ty then local s=ChessLogic.IsValidMove(b,x,y,tx,ty,c) if s then return true end end end end end end return false end
function ChessLogic.GetGameState(b,t) local e=t=="White" and "Black" or "White" local ch=ChessLogic.IsInCheck(b,t) local mv=ChessLogic.HasLegalMoves(b,t) if ch and not mv then return "Checkmate",e end if not ch and not mv then return "Stalemate",nil end if ch then return "Check",nil end return "Normal",nil end
function ChessLogic.GenerateMoves(b,c) local m={} for x=1,8 do for y=1,8 do local p=b[x][y] if p and PieceData.IsColor(p,c) then for tx=1,8 do for ty=1,8 do if x~=tx or y~=ty then local s=ChessLogic.IsValidMove(b,x,y,tx,ty,c) if s then table.insert(m,{fx=x,fy=y,tx=tx,ty=ty}) end end end end end end return m end
function ChessLogic.ApplyMove(b,fx,fy,tx,ty,pr)
	local nb=ChessLogic.CloneBoard(b); local p=nb[fx][fy]; nb[tx][ty]=p; nb[fx][fy]=nil
	if p:sub(2,2)=="P" and (ty==1 or ty==8) then local co=PieceData.GetColor(p); nb[tx][ty]=(co=="White" and "w" or "b")..(pr or "Q") end
	if p:sub(2,2)=="K" and math.abs(tx-fx)==2 then if tx==7 then nb[6][ty]=nb[8][ty];nb[8][ty]=nil elseif tx==3 then nb[4][ty]=nb[1][ty];nb[1][ty]=nil end end
	return nb
end
return ChessLogic
]]

local AISource = [[
local ChessLogic = require(script.Parent.ChessLogic)
local PieceData = require(script.Parent.PieceData)
local AI = {}
AI.Depth = 2
AI.TranspositionTable = {}
local pst={}
pst.wP={{0,0,0,0,0,0,0,0},{50,50,50,50,50,50,50,50},{10,10,20,30,30,20,10,10},{5,5,10,25,25,10,5,5},{0,0,0,20,20,0,0,0},{5,-5,-10,0,0,-10,-5,5},{5,10,10,-20,-20,10,10,5},{0,0,0,0,0,0,0,0}}
pst.bP={{0,0,0,0,0,0,0,0},{5,10,10,-20,-20,10,10,5},{5,-5,-10,0,0,-10,-5,5},{0,0,0,20,20,0,0,0},{5,5,10,25,25,10,5,5},{10,10,20,30,30,20,10,10},{50,50,50,50,50,50,50,50},{0,0,0,0,0,0,0,0}}
pst.wN={{-50,-40,-30,-30,-30,-30,-40,-50},{-40,-20,0,0,0,0,-20,-40},{-30,0,10,15,15,10,0,-30},{-30,5,15,20,20,15,5,-30},{-30,0,15,20,20,15,0,-30},{-30,5,10,15,15,10,5,-30},{-40,-20,0,5,5,0,-20,-40},{-50,-40,-30,-30,-30,-30,-40,-50}}
pst.bN={{-50,-40,-30,-30,-30,-30,-40,-50},{-40,-20,0,5,5,0,-20,-40},{-30,5,10,15,15,10,5,-30},{-30,0,15,20,20,15,0,-30},{-30,5,15,20,20,15,5,-30},{-30,0,10,15,15,10,0,-30},{-40,-20,0,0,0,0,-20,-40},{-50,-40,-30,-30,-30,-30,-40,-50}}
pst.wB={{-20,-10,-10,-10,-10,-10,-10,-20},{-10,0,0,0,0,0,0,-10},{-10,0,5,10,10,5,0,-10},{-10,5,5,10,10,5,5,-10},{-10,0,10,10,10,10,0,-10},{-10,10,10,10,10,10,10,-10},{-10,5,0,0,0,0,5,-10},{-20,-10,-10,-10,-10,-10,-10,-20}}
pst.bB={{-20,-10,-10,-10,-10,-10,-10,-20},{-10,5,0,0,0,0,5,-10},{-10,10,10,10,10,10,10,-10},{-10,0,10,10,10,10,0,-10},{-10,5,5,10,10,5,5,-10},{-10,0,5,10,10,5,0,-10},{-10,0,0,0,0,0,0,-10},{-20,-10,-10,-10,-10,-10,-10,-20}}
pst.wR={{0,0,0,0,0,0,0,0},{5,10,10,10,10,10,10,5},{-5,0,0,0,0,0,0,-5},{-5,0,0,0,0,0,0,-5},{-5,0,0,0,0,0,0,-5},{-5,0,0,0,0,0,0,-5},{-5,0,0,0,0,0,0,-5},{0,0,0,5,5,0,0,0}}
pst.bR={{0,0,0,5,5,0,0,0},{-5,0,0,0,0,0,0,-5},{-5,0,0,0,0,0,0,-5},{-5,0,0,0,0,0,0,-5},{-5,0,0,0,0,0,0,-5},{-5,0,0,0,0,0,0,-5},{5,10,10,10,10,10,10,5},{0,0,0,0,0,0,0,0}}
pst.wQ={{-20,-10,-10,-5,-5,-10,-10,-20},{-10,0,0,0,0,0,0,-10},{-10,0,5,5,5,5,0,-10},{-5,0,5,5,5,5,0,-5},{0,0,5,5,5,5,0,-5},{-10,5,5,5,5,5,0,-10},{-10,0,5,0,0,0,0,-10},{-20,-10,-10,-5,-5,-10,-10,-20}}
pst.bQ={{-20,-10,-10,-5,-5,-10,-10,-20},{-10,0,5,0,0,0,0,-10},{-10,5,5,5,5,5,0,-10},{0,0,5,5,5,5,0,-5},{-5,0,5,5,5,5,0,-5},{-10,0,5,5,5,5,0,-10},{-10,0,0,0,0,0,0,-10},{-20,-10,-10,-5,-5,-10,-10,-20}}
pst.wK={{-30,-40,-40,-50,-50,-40,-40,-30},{-30,-40,-40,-50,-50,-40,-40,-30},{-30,-40,-40,-50,-50,-40,-40,-30},{-30,-40,-40,-50,-50,-40,-40,-30},{-20,-30,-30,-40,-40,-30,-30,-20},{-10,-20,-20,-20,-20,-20,-20,-10},{20,20,0,0,0,0,20,20},{20,30,10,0,0,10,30,20}}
pst.bK={{20,30,10,0,0,10,30,20},{20,20,0,0,0,0,20,20},{-10,-20,-20,-20,-20,-20,-20,-10},{-20,-30,-30,-40,-40,-30,-30,-20},{-30,-40,-40,-50,-50,-40,-40,-30},{-30,-40,-40,-50,-50,-40,-40,-30},{-30,-40,-40,-50,-50,-40,-40,-30},{-30,-40,-40,-50,-50,-40,-40,-30}}
function AI.EvaluateBoard(b) local s=0 for x=1,8 do for y=1,8 do local p=b[x][y] if p then local v=PieceData.PieceValues[p]or 0 local t=pst[p]if t then v=v+t[y][x]end s=s+(PieceData.IsWhite(p)and v or -v)end end end return s end
local function OrderMoves(b,m) local sc={} for i,mv in ipairs(m)do local v=0 local t=b[mv.tx][mv.ty]if t then v=v+(PieceData.PieceValues[t]or 0)*10-(PieceData.PieceValues[b[mv.fx][mv.fy]]or 0)end local p=b[mv.fx][mv.fy]if p and p:sub(2,2)=="P"and(mv.ty==1 or mv.ty==8)then v=v+900 end table.insert(sc,{idx=i,score=v})end table.sort(sc,function(a,b)return a.score>b.score end)local o={}for _,s in ipairs(sc)do table.insert(o,m[s.idx])end return o end
local function BoardHash(b) local h=0 for x=1,8 do for y=1,8 do local p=b[x][y]if p then local c=p:sub(1,1)=="w"and 1 or 2 local t=string.byte(p:sub(2,2))or 0 h=h+(x*13+y*37)*(c*7+t*3)end end end return h%1000000 end
local function Minimax(b,depth,alpha,beta,maximizing,color)
	if depth==0 then return AI.EvaluateBoard(b),nil end
	local state,winner=ChessLogic.GetGameState(b,color)
	if state=="Checkmate" then return(maximizing and -100000-depth or 100000+depth),nil elseif state=="Stalemate" then return 0,nil end
	local moves=ChessLogic.GenerateMoves(b,color) if #moves==0 then return AI.EvaluateBoard(b),nil end
	local hash=BoardHash(b)+depth*1000000 local cached=AI.TranspositionTable[hash]
	if cached and cached.depth>=depth then if maximizing and cached.eval>=beta then return cached.eval,cached.move end if not maximizing and cached.eval<=alpha then return cached.eval,cached.move end end
	moves=OrderMoves(b,moves) local best=moves[1]
	if maximizing then
		local bestE=-math.huge for _,mv in ipairs(moves)do local nb=ChessLogic.ApplyMove(b,mv.fx,mv.fy,mv.tx,mv.ty)local eval=Minimax(nb,depth-1,alpha,beta,false,color=="White" and "Black" or "White")if eval>bestE then bestE=eval;best=mv end alpha=math.max(alpha,eval)if beta<=alpha then break end end
		AI.TranspositionTable[hash]={eval=bestE,depth=depth,move=best} return bestE,best
	else
		local bestE=math.huge for _,mv in ipairs(moves)do local nb=ChessLogic.ApplyMove(b,mv.fx,mv.fy,mv.tx,mv.ty)local eval=Minimax(nb,depth-1,alpha,beta,true,color=="White" and "Black" or "White")if eval<bestE then bestE=eval;best=mv end beta=math.min(beta,eval)if beta<=alpha then break end end
		AI.TranspositionTable[hash]={eval=bestE,depth=depth,move=best} return bestE,best
	end
end
function AI.FindBestMove(b,c)local moves=ChessLogic.GenerateMoves(b,c)if #moves==0 then return nil end local _,best=Minimax(b,AI.Depth,-math.huge,math.huge,c=="White",c)return best end
function AI.ClearTable()AI.TranspositionTable={}end
return AI
]]

local BoardGeneratorSource = [[
local PieceData = require(ReplicatedStorage.Modules.PieceData)
local BoardGenerator={}
local pieceColors={wP=Color3.fromRGB(240,240,240),wR=Color3.fromRGB(240,240,240),wN=Color3.fromRGB(240,240,240),wB=Color3.fromRGB(240,240,240),wQ=Color3.fromRGB(240,240,240),wK=Color3.fromRGB(240,240,240),bP=Color3.fromRGB(40,40,40),bR=Color3.fromRGB(40,40,40),bN=Color3.fromRGB(40,40,40),bB=Color3.fromRGB(40,40,40),bQ=Color3.fromRGB(40,40,40),bK=Color3.fromRGB(40,40,40)}
function BoardGenerator.Generate(pr)
	pr=pr or workspace; local ex=pr:FindFirstChild("ChessBoard")if ex then ex:Destroy()end
	local bs,ts=8,6; local f=Instance.new("Folder")f.Name="ChessBoard";f.Parent=pr
	for x=1,bs do for y=1,bs do
		local t=Instance.new("Part")t.Size=Vector3.new(ts,1,ts);t.Position=Vector3.new(x*ts,0,y*ts)
		t.Anchored=true;t.Name=x.."_"..y;t.Color=(x+y)%2==0 and Color3.fromRGB(240,217,181)or Color3.fromRGB(181,136,99)
		t.Material=Enum.Material.SmoothPlastic;t.Parent=f
	end end
	return f
end
function BoardGenerator.SyncPieces(bd,pr)
	pr=pr or workspace; local ts,ph=6,3
	local pf=pr:FindFirstChild("ChessPieces")if not pf then pf=Instance.new("Folder")pf.Name="ChessPieces";pf.Parent=pr end
	local tracked={}for _,part in ipairs(pf:GetChildren())do if part:IsA("Part")then local key=part:GetAttribute("BX").."_"..part:GetAttribute("BY")tracked[key]=part end end
	local seen={}
	for x=1,8 do for y=1,8 do
		local piece=bd[x][y]; local key=x.."_"..y; seen[key]=true
		if piece then
			local part=tracked[key]
			if part then
				if part.Name~=piece then
					part.Name=piece;part.Color=pieceColors[piece]or Color3.fromRGB(128,128,128)
					local bg=part:FindFirstChildOfClass("BillboardGui")if bg then local lbl=bg:FindFirstChildOfClass("TextLabel")if lbl then lbl.Text=PieceData.PieceSymbols[piece]or "?";lbl.TextColor3=pieceColors[piece]end end
				end
			else
				part=Instance.new("Part")part.Size=Vector3.new(ts*0.7,ph,ts*0.7);part.Anchored=true;part.Material=Enum.Material.SmoothPlastic;part.Name=piece;part.Color=pieceColors[piece]or Color3.fromRGB(128,128,128);part:SetAttribute("BX",x);part:SetAttribute("BY",y)
				local bg=Instance.new("BillboardGui")bg.Size=UDim2.new(2,0,2,0);bg.StudsOffset=Vector3.new(0,ph+1,0);bg.AlwaysOnTop=true
				local lbl=Instance.new("TextLabel")lbl.Size=UDim2.new(1,0,1,0);lbl.BackgroundTransparency=1;lbl.Text=PieceData.PieceSymbols[piece]or "?";lbl.TextColor3=pieceColors[piece];lbl.TextScaled=true;lbl.Font=Enum.Font.GothamBold;lbl.Parent=bg;bg.Parent=part;part.Parent=pf
			end
			part.Position=Vector3.new(x*ts,ph/2,y*ts)
		end
	end end
	for key,part in pairs(tracked)do if not seen[key]then part:Destroy()end end
end
return BoardGenerator
]]

local GameManagerSource = [[
local ChessLogic=require(ReplicatedStorage.Modules.ChessLogic)
local PieceData=require(ReplicatedStorage.Modules.PieceData)
local AI=require(ReplicatedStorage.Modules.AI)
local BoardGenerator=require(script.Parent.BoardGenerator)
local GameManager={};GameManager.ActiveGames={}
function GameManager.NewGame(gid,pw,pb,ai)
	local self={GameId=gid or tostring(os.clock()),Players={White=pw,Black=pb},AIOpponent=ai or false,Board=ChessLogic.NewBoard(),Turn="White",MoveHistory={},MoveCount=0,HalfMoveClock=0,FullMoveNumber=1,CastlingRights="KQkq",EnPassantTarget=nil,GameOver=false,Winner=nil,GameState="Normal",Timers={White=600,Black=600},TimerRunning=false,LastTick=os.clock(),SelectedPos=nil,Remotes=ReplicatedStorage:FindFirstChild("ChessRemotes")}
	setmetatable(self,{__index=GameManager});GameManager.ActiveGames[self.GameId]=self;return self
end
function GameManager:Start()
	BoardGenerator.Generate(workspace);BoardGenerator.SyncPieces(self.Board,workspace);self.TimerRunning=true;self.LastTick=os.clock();self:StartTimerLoop();self:BroadcastState()
end
function GameManager:StartTimerLoop()
	task.spawn(function()while not self.GameOver and self.TimerRunning do local now=os.clock();local dt=now-(self.LastTick or now);self.LastTick=now;if self.Timers[self.Turn]then self.Timers[self.Turn]=math.max(0,self.Timers[self.Turn]-dt)if self.Timers[self.Turn]<=0 then self.GameOver=true;self.Winner=self.Turn=="White" and "Black" or "White";self.GameState="Timeout";self:BroadcastState();self:BroadcastEvent("GameOver",{Winner=self.Winner,Reason="Timeout"});return end end;self:BroadcastEvent("TimerUpdate",{WhiteTime=self.Timers.White,BlackTime=self.Timers.Black});task.wait(0.5)end end)
end
function GameManager:MakeMove(fx,fy,tx,ty,player,pr)
	if self.GameOver then return false,"Game over" end
	local pc=nil;for c,n in pairs(self.Players)do if n==player then pc=c;break end end
	if not pc then return false,"Not in game" end;if pc~=self.Turn then return false,"Not your turn" end;if self.AIOpponent and pc=="Black" then return false,"AI controls black" end
	local valid,ex=ChessLogic.IsValidMove(self.Board,fx,fy,tx,ty,self.Turn,self.CastlingRights,self.EnPassantTarget)
	if not valid then return false,"Invalid move" end
	local piece=self.Board[fx][fy]; local capturedPiece=self.Board[tx][ty]
	self.Board=ChessLogic.ApplyMove(self.Board,fx,fy,tx,ty,pr)
	local fn=string.char(96+fx)..fy;local tn=string.char(96+tx)..ty;table.insert(self.MoveHistory,{Piece=piece,From=fn,To=tn,Player=pc,MoveNumber=self.FullMoveNumber,Captured=capturedPiece})
	if self.Turn=="Black" then self.FullMoveNumber=self.FullMoveNumber+1 end
	if piece and piece:sub(2,2)=="P"or capturedPiece then self.HalfMoveClock=0 else self.HalfMoveClock=self.HalfMoveClock+1 end
	self:UpdateEnPassant(fx,fy,tx,ty,piece)
	if fx==1 and fy==1 then self.CastlingRights=self.CastlingRights:gsub("Q","")elseif fx==8 and fy==1 then self.CastlingRights=self.CastlingRights:gsub("K","")elseif fx==1 and fy==8 then self.CastlingRights=self.CastlingRights:gsub("q","")elseif fx==8 and fy==8 then self.CastlingRights=self.CastlingRights:gsub("k","")elseif piece and piece:sub(2,2)=="K"then if PieceData.IsWhite(piece)then self.CastlingRights=self.CastlingRights:gsub("[KQ]","")else self.CastlingRights=self.CastlingRights:gsub("[kq]","")end end
	if self.CastlingRights==""then self.CastlingRights="-"end
	self.Turn=self.Turn=="White" and "Black" or "White"
	local state,winner=ChessLogic.GetGameState(self.Board,self.Turn);self.GameState=state
	if state=="Checkmate" then self.GameOver=true;self.Winner=self.Turn=="White" and "Black" or "White" elseif state=="Stalemate" then self.GameOver=true;self.Winner="Draw" end
	BoardGenerator.SyncPieces(self.Board,workspace);self:BroadcastState()
	if self.GameOver then self.TimerRunning=false;AI.ClearTable();self:BroadcastEvent("GameOver",{Winner=self.Winner,Reason=self.GameState})end
	if not self.GameOver and self.AIOpponent and self.Turn=="Black" then self:ScheduleAIMove()end;return true
end
function GameManager:UpdateEnPassant(fx,fy,tx,ty,p)self.EnPassantTarget=nil if p and p:sub(2,2)=="P"and math.abs(ty-fy)==2 then self.EnPassantTarget={x=fx,y=(fy+ty)/2}end end
function GameManager:ScheduleAIMove()task.spawn(function()task.wait(0.5)if self.GameOver then return end;local m=AI.FindBestMove(self.Board,"Black")if m then self:MakeMove(m.fx,m.fy,m.tx,m.ty,self.Players.Black)end end)end
function GameManager:GetValidMovesFor(x,y)local p=self.Board[x][y]if not p then return{}end local c=PieceData.GetColor(p)if c~=self.Turn then return{}end local m={}for tx=1,8 do for ty=1,8 do if x~=tx or y~=ty then local s=ChessLogic.IsValidMove(self.Board,x,y,tx,ty,c)if s then table.insert(m,{x=tx,y=ty})end end end end return m end
function GameManager:BroadcastState()if not self.Remotes then return end;local r=self.Remotes:FindFirstChild("UpdateState")if r then r:FireAllClients({Board=self.Board,Turn=self.Turn,GameState=self.GameState,Players=self.Players,MoveHistory=self.MoveHistory,GameOver=self.GameOver,Winner=self.Winner})end end
function GameManager:BroadcastEvent(n,d)if not self.Remotes then return end;local r=self.Remotes:FindFirstChild(n)if r then r:FireAllClients(d)end end
function GameManager:Resign(player)local c=nil for cl,n in pairs(self.Players)do if n==player then c=cl;break end end if not c then return false end;self.GameOver=true;self.Winner=c=="White" and "Black" or "White";self.TimerRunning=false;self:BroadcastState();self:BroadcastEvent("GameOver",{Winner=self.Winner,Reason="Resignation"});return true end
return GameManager
]]

local MatchSystemSource = [[
local MatchSystem={};MatchSystem.Queue={};MatchSystem.EloK=32;MatchSystem.DefaultElo=1200
local DataStoreService=game:GetService("DataStoreService");local eloStore=nil
local function Init()local s,r=pcall(function()return DataStoreService:GetDataStore("ChessEloData")end)if s then eloStore=r end end
function MatchSystem.GetElo(uid)if not eloStore then Init()end if not eloStore then return MatchSystem.DefaultElo end;local s,d=pcall(function()return eloStore:GetAsync(tostring(uid))end)if s and d then return d end return MatchSystem.DefaultElo end
function MatchSystem.SaveElo(uid,elo)if not eloStore then Init()end if not eloStore then return end;pcall(function()eloStore:SetAsync(tostring(uid),elo)end)end
function MatchSystem.CalculateElo(ra,rb,sa)local ea=1/(1+math.pow(10,(rb-ra)/400))local eb=1-ea local na=ra+MatchSystem.EloK*(sa-ea)local nb=rb+MatchSystem.EloK*((1-sa)-eb)return math.floor(na),math.floor(nb)end
function MatchSystem.AddToQueue(p)for _,e in ipairs(MatchSystem.Queue)do if e.Player==p then return false,"Already in queue"end end;local elo=MatchSystem.GetElo(p.UserId)table.insert(MatchSystem.Queue,{Player=p,Elo=elo,JoinTime=os.clock()});MatchSystem.BroadcastQueueUpdate();return true end
function MatchSystem.RemoveFromQueue(p)for i,e in ipairs(MatchSystem.Queue)do if e.Player==p then table.remove(MatchSystem.Queue,i);MatchSystem.BroadcastQueueUpdate();return true end end return false end
function MatchSystem.TryMatchPlayers()if #MatchSystem.Queue<2 then return nil end;local bd=math.huge;local bp=nil;for i=1,#MatchSystem.Queue do for j=i+1,#MatchSystem.Queue do local d=math.abs(MatchSystem.Queue[i].Elo-MatchSystem.Queue[j].Elo)if d<bd then bd=d;bp={i,j}end end end;if bp and bd<=400 then local pA=MatchSystem.Queue[bp[1]];local pB=MatchSystem.Queue[bp[2]];table.remove(MatchSystem.Queue,bp[2]);table.remove(MatchSystem.Queue,bp[1]);MatchSystem.BroadcastQueueUpdate();return{pA.Player,pB.Player}end;return nil end
function MatchSystem.BroadcastQueueUpdate()local r=ReplicatedStorage:FindFirstChild("ChessRemotes")if not r then return end;local q=r:FindFirstChild("QueueUpdate")if not q then return end;local d={}for _,e in ipairs(MatchSystem.Queue)do table.insert(d,{PlayerName=e.Player.Name,Elo=e.Elo})end;q:FireAllClients(d)end
function MatchSystem.HandleGameEnd(gid,wc,pw,pb)local we=MatchSystem.GetElo(pw.UserId);local be=MatchSystem.GetElo(pb.UserId);local sa=0.5 if wc=="White"then sa=1 elseif wc=="Black"then sa=0 end;local nwe,nbe=MatchSystem.CalculateElo(we,be,sa);MatchSystem.SaveElo(pw.UserId,nwe);MatchSystem.SaveElo(pb.UserId,nbe);local r=ReplicatedStorage:FindFirstChild("ChessRemotes")if not r then return end;local eu=r:FindFirstChild("EloUpdate")if eu then eu:FireClient(pw,{OldElo=we,NewElo=nwe,Change=nwe-we});eu:FireClient(pb,{OldElo=be,NewElo=nbe,Change=nbe-be})end end
Init()
return MatchSystem
]]

local ChessServerSource = [[
local Players=game:GetService("Players")
local ChessLogic=require(ReplicatedStorage.Modules.ChessLogic)
local PieceData=require(ReplicatedStorage.Modules.PieceData)
local AI=require(ReplicatedStorage.Modules.AI)
local GameManager=require(script.GameManager)
local MatchSystem=require(script.MatchSystem)
local BoardGenerator=require(script.BoardGenerator)

local remotes=Instance.new("Folder")remotes.Name="ChessRemotes";remotes.Parent=ReplicatedStorage
local function mk(n,t)t=t or "RemoteEvent"local r=Instance.new(t)r.Name=n;r.Parent=remotes;return r end
mk("UpdateState");mk("TimerUpdate");mk("GameOver");mk("QueueUpdate");mk("EloUpdate");mk("GameStart");mk("TileSelected")
local selectTile=mk("SelectTile");local joinQueue=mk("JoinQueue");local leaveQueue=mk("LeaveQueue");local resignRemote=mk("Resign");local startAI=mk("StartAI")

local debounce={}
selectTile.OnServerEvent:Connect(function(player,tileName)
	local now=tick()if debounce[player]and now-debounce[player]<0.15 then return end;debounce[player]=now
	local xS,yS=tileName:match("(%d+)_(%d+)")if not xS or not yS then return end;local x,y=tonumber(xS),tonumber(yS)
	for _,g in pairs(GameManager.ActiveGames)do
		local pc=nil;for c,n in pairs(g.Players)do if n==player then pc=c;break end end
		if pc then
			if not g.SelectedPos then
				local p=g.Board[x][y]if p and PieceData.IsColor(p,pc)then
					g.SelectedPos={x=x,y=y};local valid=g:GetValidMovesFor(x,y)
					g:BroadcastEvent("TileSelected",{Player=pc,X=x,Y=y,ValidMoves=valid})
				end
			else local fx,fy=g.SelectedPos.x,g.SelectedPos.y;g.SelectedPos=nil;g:MakeMove(fx,fy,x,y,player)end;return
		end
	end
end)

joinQueue.OnServerEvent:Connect(function(player)
	local s,err=MatchSystem.AddToQueue(player)if not s then return end
	task.spawn(function()
		task.wait(0.5)
		local match=MatchSystem.TryMatchPlayers()
		if match then
			local pA,pB=match[1],match[2];local coin=math.random(2)==1;local wp,bp=coin and pA or pB,coin and pB or pA
			local gid="GAME_"..os.time().."_"..math.random(1000,9999);local g=GameManager.NewGame(gid,wp,bp)
			local gs=remotes:FindFirstChild("GameStart")if gs then gs:FireClient(wp,{Color="White",Opponent=bp.Name});gs:FireClient(bp,{Color="Black",Opponent=wp.Name})end;g:Start()
		end
	end)
end)

leaveQueue.OnServerEvent:Connect(function(player)MatchSystem.RemoveFromQueue(player)end)
resignRemote.OnServerEvent:Connect(function(player)for _,g in pairs(GameManager.ActiveGames)do for _,n in pairs(g.Players)do if n==player then g:Resign(player);MatchSystem.HandleGameEnd(g.GameId,g.Winner,g.Players.White,g.Players.Black);return end end end end)
startAI.OnServerEvent:Connect(function(player)local gid="AI_"..os.time().."_"..player.UserId;local g=GameManager.NewGame(gid,player,player,true);local gs=remotes:FindFirstChild("GameStart")if gs then gs:FireClient(player,{Color="White",Opponent="Chess AI"})end;g:Start()end)

Players.PlayerRemoving:Connect(function(player)
	MatchSystem.RemoveFromQueue(player)
	for _,g in pairs(GameManager.ActiveGames)do for c,n in pairs(g.Players)do if n==player then local oc=c=="White" and "Black" or "White";g.GameOver=true;g.Winner=oc;g.TimerRunning=false;g:BroadcastState();g:BroadcastEvent("GameOver",{Winner=oc,Reason="Opponent disconnected"});MatchSystem.HandleGameEnd(g.GameId,oc,g.Players.White,g.Players.Black);return end end end
end)

local om=GameManager.MakeMove
function GameManager:MakeMove(...)local r=om(self,...)if self.GameOver and not self.AIOpponent then MatchSystem.HandleGameEnd(self.GameId,self.Winner,self.Players.White,self.Players.Black)end;return r end

warn("Chess server loaded")
]]

local ChessClientSource = [[
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local Player=Players.LocalPlayer
local PlayerGui=Player:WaitForChild("PlayerGui")
local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("ChessRemotes")
if not remotes then return end

local sg=Instance.new("ScreenGui")sg.Name="ChessUI";sg.ResetOnSpawn=false
local function ml(pos,txt,color)local l=Instance.new("TextLabel")l.Size=UDim2.new(0,200,0,30);l.Position=pos;l.BackgroundTransparency=1;l.Text=txt;l.TextColor3=color or Color3.fromRGB(255,255,255);l.TextScaled=true;l.Font=Enum.Font.GothamBold;l.Parent=sg;return l end
local function mb(pos,txt,color,cb)local b=Instance.new("TextButton")b.Size=UDim2.new(0,200,0,50);b.Position=pos;b.BackgroundColor3=color or Color3.fromRGB(40,40,40);b.BackgroundTransparency=0.3;b.Text=txt;b.TextColor3=Color3.fromRGB(255,255,255);b.TextScaled=true;b.Font=Enum.Font.GothamBold;local c=Instance.new("UICorner")c.CornerRadius=UDim.new(0,8);c.Parent=b;b.MouseButton1Click:Connect(cb);b.Parent=sg;return b end
local gi=ml(UDim2.new(0.5,-100,0,10),"Chess",Color3.fromRGB(255,255,255))
ml(UDim2.new(0.5,-100,0,40),"",Color3.fromRGB(200,200,200))
local wt=ml(UDim2.new(0,20,0,20),"10:00",Color3.fromRGB(255,255,255))
local bt=ml(UDim2.new(0,20,0,80),"10:00",Color3.fromRGB(255,255,255))
local hls={}
mb(UDim2.new(0.5,-100,0,100),"Join Queue",Color3.fromRGB(40,40,80),function()local r=remotes:FindFirstChild("JoinQueue")if r then r:FireServer()end end)
mb(UDim2.new(0.5,-100,0,170),"Play vs AI",Color3.fromRGB(40,80,40),function()local r=remotes:FindFirstChild("StartAI")if r then r:FireServer()end end)
local rb=mb(UDim2.new(0,20,0,140),"Resign",Color3.fromRGB(180,40,40),function()local r=remotes:FindFirstChild("Resign")if r then r:FireServer()end end);rb.Visible=false
mb(UDim2.new(0.5,-100,0,240),"Leave Queue",Color3.fromRGB(80,40,40),function()local r=remotes:FindFirstChild("LeaveQueue")if r then r:FireServer()end end)
local us=remotes:FindFirstChild("UpdateState")if us then us.OnClientEvent:Connect(function(d)if d.GameState=="Check"then gi.Text="Check!";gi.TextColor3=Color3.fromRGB(255,200,0)elseif d.GameState=="Checkmate"then local wn="Unknown";for c,n in pairs(d.Players or{})do if c==d.Winner then wn=n end end;gi.Text="Checkmate! "..wn.." wins!";gi.TextColor3=Color3.fromRGB(255,215,0)elseif d.GameState=="Stalemate"then gi.Text="Stalemate - Draw!";gi.TextColor3=Color3.fromRGB(200,200,200)elseif d.GameState=="Timeout"then gi.Text="Timeout! "..(d.Winner or "?").." wins";gi.TextColor3=Color3.fromRGB(255,200,0)else gi.Text="Chess";gi.TextColor3=Color3.fromRGB(255,255,255)end;if d.GameOver then rb.Visible=false end end)end
local tu=remotes:FindFirstChild("TimerUpdate")if tu then tu.OnClientEvent:Connect(function(d)if d.WhiteTime then local m=math.floor(d.WhiteTime/60);local s=math.floor(d.WhiteTime%60);wt.Text=string.format("%d:%02d",m,s);wt.TextColor3=d.WhiteTime<60 and Color3.fromRGB(255,50,50)or Color3.fromRGB(255,255,255)end;if d.BlackTime then local m=math.floor(d.BlackTime/60);local s=math.floor(d.BlackTime%60);bt.Text=string.format("%d:%02d",m,s);bt.TextColor3=d.BlackTime<60 and Color3.fromRGB(255,50,50)or Color3.fromRGB(255,255,255)end end)end
local gs=remotes:FindFirstChild("GameStart")if gs then gs.OnClientEvent:Connect(function(d)rb.Visible=true end)end
local ts=remotes:FindFirstChild("TileSelected")if ts then ts.OnClientEvent:Connect(function(d)for _,h in ipairs(hls)do pcall(function()h:Destroy()end)end;hls={};local board=workspace:FindFirstChild("ChessBoard")if not board then return end;local tile=board:FindFirstChild(d.X.."_"..d.Y)if tile then local sel=Instance.new("SelectionBox")sel.Adornee=tile;sel.Color3=Color3.fromRGB(255,255,0);sel.LineThickness=0.08;sel.Transparency=0.3;sel.Parent=tile;table.insert(hls,sel)end;if d.ValidMoves then for _,m in ipairs(d.ValidMoves)do local mt=board:FindFirstChild(m.x.."_"..m.y)if mt then local h=Instance.new("SelectionBox")h.Adornee=mt;h.Color3=Color3.fromRGB(0,255,100);h.LineThickness=0.05;h.Transparency=0.5;h.Parent=mt;table.insert(hls,h)end end end end)end
UserInputService.InputBegan:Connect(function(input,gp)if gp then return end;if input.UserInputType==Enum.UserInputType.MouseButton1 then local mouse=Player:GetMouse();local target=mouse.Target;if target then local board=workspace:FindFirstChild("ChessBoard")if board and target.Parent==board then local st=remotes:FindFirstChild("SelectTile")if st then st:FireServer(target.Name)end end end end end)
sg.Parent=PlayerGui
]]

--===========================================================
-- INJECTOR: Create instances in the game hierarchy
--===========================================================

local function EnsureFolder(path)
	local parts = path:split("/")
	local current = game
	for _, name in ipairs(parts) do
		local child = current:FindFirstChild(name)
		if not child then
			child = Instance.new("Folder")
			child.Name = name
			child.Parent = current
		end
		current = child
	end
	return current
end

local function CreateModule(parent, name, source)
	local existing = parent:FindFirstChild(name)
	if existing then existing:Destroy() end
	local m = Instance.new("ModuleScript")
	m.Name = name
	m.Source = source
	m.Parent = parent
	return m
end

local function CreateScript(parent, name, source)
	local existing = parent:FindFirstChild(name)
	if existing then existing:Destroy() end
	local s = Instance.new("Script")
	s.Name = name
	s.Source = source
	s.Parent = parent
	return s
end

local function CreateLocalScript(parent, name, source)
	local existing = parent:FindFirstChild(name)
	if existing then existing:Destroy() end
	local s = Instance.new("LocalScript")
	s.Name = name
	s.Source = source
	s.Parent = parent
	return s
end

if isServer then
	-- Create Modules folder in ReplicatedStorage
	local modulesFolder = EnsureFolder("ReplicatedStorage/Modules")
	CreateModule(modulesFolder, "PieceData", PieceDataSource)
	CreateModule(modulesFolder, "ChessLogic", ChessLogicSource)
	CreateModule(modulesFolder, "AI", AISource)

	-- Create ChessServer folder
	local serverFolder = EnsureFolder("ServerScriptService/ChessServer")
	CreateModule(serverFolder, "BoardGenerator", BoardGeneratorSource)
	CreateModule(serverFolder, "GameManager", GameManagerSource)
	CreateModule(serverFolder, "MatchSystem", MatchSystemSource)
	CreateScript(serverFolder, "ChessServer", ChessServerSource)

	warn("Chess system installed to server. Board generating...")
	task.wait(0.5)

	-- Run the server script
	local serverScript = serverFolder:FindFirstChild("ChessServer")
	if serverScript then
		serverScript.Disabled = false
	end

elseif isClient then
	-- Create client local script
	local sps = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if not sps then
		sps = Instance.new("StarterPlayerScripts")
		sps.Name = "StarterPlayerScripts"
		sps.Parent = StarterPlayer
	end

	CreateLocalScript(sps, "ChessClient", ChessClientSource)
	warn("Chess client installed. Rejoin or reset character.")
end
]]

