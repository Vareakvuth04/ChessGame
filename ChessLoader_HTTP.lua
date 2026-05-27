--[[
	Roblox Chess Game - Client-Side Only
	Execute this in any Roblox game.
	Supports: 2-player hotseat, vs AI, timers, all chess rules.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

print("Chess loader v2: waiting for PlayerGui...")
local PlayerGui = Player:WaitForChild("PlayerGui", 30)
if not PlayerGui then print("ERROR: No PlayerGui found"); return end
print("Chess loader: PlayerGui ready")

--===========================================================
-- PIECE DATA
--===========================================================
local PieceData = {}
PieceData.PieceValues = {
	wP=100,wN=320,wB=330,wR=500,wQ=900,wK=20000,
	bP=100,bN=320,bB=330,bR=500,bQ=900,bK=20000
}
PieceData.PieceSymbols = {
	wP="♙",wN="♘",wB="♗",wR="♖",wQ="♕",wK="♔",
	bP="♟",bN="♞",bB="♝",bR="♜",bQ="♛",bK="♚"
}
PieceData.PieceColors = {
	wP=Color3.fromRGB(240,240,240),wR=Color3.fromRGB(240,240,240),
	wN=Color3.fromRGB(240,240,240),wB=Color3.fromRGB(240,240,240),
	wQ=Color3.fromRGB(240,240,240),wK=Color3.fromRGB(240,240,240),
	bP=Color3.fromRGB(40,40,40),bR=Color3.fromRGB(40,40,40),
	bN=Color3.fromRGB(40,40,40),bB=Color3.fromRGB(40,40,40),
	bQ=Color3.fromRGB(40,40,40),bK=Color3.fromRGB(40,40,40)
}
function PieceData.GetColor(p) return p and(p:sub(1,1)=="w"and"White"or"Black")or nil end
function PieceData.IsColor(p,c) return p and((c=="White"and p:sub(1,1)=="w")or(c=="Black"and p:sub(1,1)=="b"))end

--===========================================================
-- CHESS LOGIC
--===========================================================
local ChessLogic = {}
function ChessLogic.NewBoard()
	local b={}for x=1,8 do b[x]={}end
	local r={"R","N","B","Q","K","B","N","R"}
	for x=1,8 do b[x][1]="w"..r[x];b[x][2]="wP";b[x][7]="bP";b[x][8]="b"..r[x]end
	return b
end
function ChessLogic.CloneBoard(b)local c={}for x=1,8 do c[x]={}for y=1,8 do c[x][y]=b[x][y]end end return c end
function ChessLogic.InBounds(x,y)return x>=1 and x<=8 and y>=1 and y<=8 end
function ChessLogic.IsValidPawnMove(b,fx,fy,tx,ty,c,ep)
	local d=c=="White"and 1 or-1;local sr=c=="White"and 2 or 7
	if tx==fx and ty==fy+d and not b[tx][ty]then return true end
	if tx==fx and ty==fy+2*d and fy==sr then local my=fy+d;if not b[tx][ty]and not b[tx][my]then return true end end
	if math.abs(tx-fx)==1 and ty==fy+d then
		if b[tx][ty]and PieceData.IsColor(b[tx][ty],c=="White"and"Black"or"White")then return true end
		if ep and tx==ep.x and ty==ep.y then return true end
	end
	return false
end
function ChessLogic.IsValidKnightMove(b,fx,fy,tx,ty,c)
	local dx,dy=math.abs(tx-fx),math.abs(ty-fy)
	if not((dx==2 and dy==1)or(dx==1 and dy==2))then return false end
	local t=b[tx][ty]if t and PieceData.IsColor(t,c)then return false end;return true
end
function ChessLogic.IsValidBishopMove(b,fx,fy,tx,ty,c)
	if math.abs(tx-fx)~=math.abs(ty-fy)then return false end
	local sx,sy=tx>fx and 1 or-1,ty>fy and 1 or-1;local x,y=fx+sx,fy+sy
	while x~=tx or y~=ty do if b[x][y]then return false end x=x+sx;y=y+sy end
	local t=b[tx][ty]if t and PieceData.IsColor(t,c)then return false end;return true
end
function ChessLogic.IsValidRookMove(b,fx,fy,tx,ty,c)
	if fx~=tx and fy~=ty then return false end
	if fx==tx then local sy=ty>fy and 1 or-1;local y=fy+sy while y~=ty do if b[fx][y]then return false end y=y+sy end
	else local sx=tx>fx and 1 or-1;local x=fx+sx while x~=tx do if b[x][fy]then return false end x=x+sx end end
	local t=b[tx][ty]if t and PieceData.IsColor(t,c)then return false end;return true
end
function ChessLogic.IsValidQueenMove(b,fx,fy,tx,ty,c)return ChessLogic.IsValidBishopMove(b,fx,fy,tx,ty,c)or ChessLogic.IsValidRookMove(b,fx,fy,tx,ty,c)end
function ChessLogic.IsValidKingMove(b,fx,fy,tx,ty,c)
	local dx,dy=math.abs(tx-fx),math.abs(ty-fy)
	if dx<=1 and dy<=1 and dx+dy>0 then local t=b[tx][ty]if t and PieceData.IsColor(t,c)then return false end return true end
	if dx==2 and dy==0 then
		local row=fy;local e=c=="White"and"Black"or"White"
		if tx==7 then if b[8][row]==(c=="White"and"wR"or"bR")and not b[6][row]and not b[7][row]and not ChessLogic.IsSquareAttacked(b,fx,fy,e)and not ChessLogic.IsSquareAttacked(b,fx+1,fy,e)and not ChessLogic.IsSquareAttacked(b,fx+2,fy,e)then return true,"kingside"end
		elseif tx==3 then if b[1][row]==(c=="White"and"wR"or"bR")and not b[2][row]and not b[3][row]and not b[4][row]and not ChessLogic.IsSquareAttacked(b,fx,fy,e)and not ChessLogic.IsSquareAttacked(b,fx-1,fy,e)and not ChessLogic.IsSquareAttacked(b,fx-2,fy,e)then return true,"queenside"end end
	end
	return false
end
function ChessLogic.IsValidMove(b,fx,fy,tx,ty,c,ep)
	if not ChessLogic.InBounds(fx,fy)or not ChessLogic.InBounds(tx,ty)then return false end
	local p=b[fx][fy]if not p or not PieceData.IsColor(p,c)then return false end
	local pt=p:sub(2,2);local v,ex=false,nil
	if pt=="P"then v=ChessLogic.IsValidPawnMove(b,fx,fy,tx,ty,c,ep)
	elseif pt=="N"then v=ChessLogic.IsValidKnightMove(b,fx,fy,tx,ty,c)
	elseif pt=="B"then v=ChessLogic.IsValidBishopMove(b,fx,fy,tx,ty,c)
	elseif pt=="R"then v=ChessLogic.IsValidRookMove(b,fx,fy,tx,ty,c)
	elseif pt=="Q"then v=ChessLogic.IsValidQueenMove(b,fx,fy,tx,ty,c)
	elseif pt=="K"then local s,e=ChessLogic.IsValidKingMove(b,fx,fy,tx,ty,c);v=s;ex=e end
	if not v then return false end
	local t=ChessLogic.CloneBoard(b);t[tx][ty]=t[fx][fy];t[fx][fy]=nil
	if ex=="kingside"then t[tx-1][ty]=t[tx+1][ty];t[tx+1][ty]=nil
	elseif ex=="queenside"then t[tx+1][ty]=t[tx-2][ty];t[tx-2][ty]=nil end
	if ChessLogic.IsInCheck(t,c)then return false end;return true,ex
end
function ChessLogic.FindKing(b,c)local k=c=="White"and"wK"or"bK"for x=1,8 do for y=1,8 do if b[x][y]==k then return x,y end end end return nil,nil end
function ChessLogic.IsSquareAttacked(b,tx,ty,by)
	for x=1,8 do for y=1,8 do
		local p=b[x][y]if p and PieceData.IsColor(p,by)then
			local pt=p:sub(2,2)
			if pt=="P"then local d=by=="White"and 1 or-1;if math.abs(tx-x)==1 and ty==y+d then return true end
			elseif pt=="N"then local dx,dy=math.abs(tx-x),math.abs(ty-y)if(dx==2 and dy==1)or(dx==1 and dy==2)then return true end
			elseif pt=="B"then
				if math.abs(tx-x)==math.abs(ty-y)and tx~=x then
					local sx,sy=tx>x and 1 or-1,ty>y and 1 or-1;local cx,cy=x+sx,y+sy;local bl=false
					while cx~=tx or cy~=ty do if b[cx][cy]then bl=true;break end cx=cx+sx;cy=cy+sy end
					if not bl then return true end
				end
			elseif pt=="R"then
				if x==tx or y==ty then
					if x==tx and y~=ty then local s=ty>y and 1 or-1;local cy=y+s;local bl=false while cy~=ty do if b[x][cy]then bl=true;break end cy=cy+s end if not bl then return true end
					elseif y==ty then local s=tx>x and 1 or-1;local cx=x+s;local bl=false while cx~=tx do if b[cx][y]then bl=true;break end cx=cx+s end if not bl then return true end
				end
			elseif pt=="Q"then
				if math.abs(tx-x)==math.abs(ty-y)or tx==x or ty==y then
					if math.abs(tx-x)==math.abs(ty-y)then
						local sx,sy=tx>x and 1 or-1,ty>y and 1 or-1;local cx,cy=x+sx,y+sy;local bl=false
						while cx~=tx or cy~=ty do if b[cx][cy]then bl=true;break end cx=cx+sx;cy=cy+sy end
						if not bl then return true end
					elseif x==tx then local s=ty>y and 1 or-1;local cy=y+s;local bl=false while cy~=ty do if b[x][cy]then bl=true;break end cy=cy+s end if not bl then return true end
					elseif y==ty then local s=tx>x and 1 or-1;local cx=x+s;local bl=false while cx~=tx do if b[cx][y]then bl=true;break end cx=cx+s end if not bl then return true end
				end
			elseif pt=="K"then local dx,dy=math.abs(tx-x),math.abs(ty-y)if dx<=1 and dy<=1 and dx+dy>0 then return true end
			end
		end
	end end
	return false
end
function ChessLogic.IsInCheck(b,c)local kx,ky=ChessLogic.FindKing(b,c)if not kx then return false end;local e=c=="White"and"Black"or"White";return ChessLogic.IsSquareAttacked(b,kx,ky,e)end
function ChessLogic.HasLegalMoves(b,c)for x=1,8 do for y=1,8 do local p=b[x][y]if p and PieceData.IsColor(p,c)then for tx=1,8 do for ty=1,8 do if x~=tx or y~=ty then local s=ChessLogic.IsValidMove(b,x,y,tx,ty,c)if s then return true end end end end end end return false end
function ChessLogic.GetGameState(b,t)local e=t=="White"and"Black"or"White";local ch=ChessLogic.IsInCheck(b,t);local mv=ChessLogic.HasLegalMoves(b,t)if ch and not mv then return"Checkmate",e end;if not ch and not mv then return"Stalemate",nil end;if ch then return"Check",nil end;return"Normal",nil end
function ChessLogic.GenerateMoves(b,c)local m={}for x=1,8 do for y=1,8 do local p=b[x][y]if p and PieceData.IsColor(p,c)then for tx=1,8 do for ty=1,8 do if x~=tx or y~=ty then local s=ChessLogic.IsValidMove(b,x,y,tx,ty,c)if s then table.insert(m,{fx=x,fy=y,tx=tx,ty=ty})end end end end end end return m end
function ChessLogic.ApplyMove(b,fx,fy,tx,ty,pr)
	local nb=ChessLogic.CloneBoard(b);local p=nb[fx][fy];nb[tx][ty]=p;nb[fx][fy]=nil
	if p:sub(2,2)=="P"and(ty==1 or ty==8)then local co=PieceData.GetColor(p);nb[tx][ty]=(co=="White"and"w"or"b")..(pr or"Q")end
	if p:sub(2,2)=="K"and math.abs(tx-fx)==2 then if tx==7 then nb[6][ty]=nb[8][ty];nb[8][ty]=nil elseif tx==3 then nb[4][ty]=nb[1][ty];nb[1][ty]=nil end end
	return nb
end

--===========================================================
-- AI (depth 2 + transposition table)
--===========================================================
local AI={Depth=2,TT={}}
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
function AI.Eval(b)local s=0 for x=1,8 do for y=1,8 do local p=b[x][y]if p then local v=PieceData.PieceValues[p]or 0 local t=pst[p]if t then v=v+t[y][x]end s=s+(p:sub(1,1)=="w"and v or -v)end end end return s end
local function Order(b,m)local sc={}for i,mv in ipairs(m)do local v=0;local t=b[mv.tx][mv.ty]if t then v=v+(PieceData.PieceValues[t]or 0)*10 end;local p=b[mv.fx][mv.fy]if p and p:sub(2,2)=="P"and(mv.ty==1 or mv.ty==8)then v=v+900 end;table.insert(sc,{idx=i,score=v})end;table.sort(sc,function(a,b)return a.score>b.score end)local o={}for _,s in ipairs(sc)do table.insert(o,m[s.idx])end;return o end
local function Hash(b)local h=0 for x=1,8 do for y=1,8 do local p=b[x][y]if p then h=h+(x*13+y*37)*(string.byte(p))end end end return h%1000000 end
local function Search(b,depth,alpha,beta,max,c)
	if depth==0 then return AI.Eval(b),nil end
	local st,wn=ChessLogic.GetGameState(b,c)
	if st=="Checkmate"then return(max and-100000-depth or 100000+depth),nil elseif st=="Stalemate"then return 0,nil end
	local moves=ChessLogic.GenerateMoves(b,c)if #moves==0 then return AI.Eval(b),nil end
	local h=Hash(b)+depth*1000000;local ca=AI.TT[h]if ca and ca.d>=depth then if max and ca.e>=beta then return ca.e,ca.m end;if not max and ca.e<=alpha then return ca.e,ca.m end end
	moves=Order(b,moves)local best=moves[1]
	if max then
		local be=-math.huge for _,mv in ipairs(moves)do local nb=ChessLogic.ApplyMove(b,mv.fx,mv.fy,mv.tx,mv.ty)local e=Search(nb,depth-1,alpha,beta,false,c=="White"and"Black"or"White")if e>be then be=e;best=mv end;alpha=math.max(alpha,e)if beta<=alpha then break end end
		AI.TT[h]={e=be,d=depth,m=best};return be,best
	else
		local be=math.huge for _,mv in ipairs(moves)do local nb=ChessLogic.ApplyMove(b,mv.fx,mv.fy,mv.tx,mv.ty)local e=Search(nb,depth-1,alpha,beta,true,c=="White"and"Black"or"White")if e<be then be=e;best=mv end;beta=math.min(beta,e)if beta<=alpha then break end end
		AI.TT[h]={e=be,d=depth,m=best};return be,best
	end
end
function AI.BestMove(b,c)local moves=ChessLogic.GenerateMoves(b,c)if #moves==0 then return nil end;local _,best=Search(b,AI.Depth,-math.huge,math.huge,c=="White",c)return best end

--===========================================================
-- GAME STATE
--===========================================================
local Game = {
	Board = ChessLogic.NewBoard(),
	Turn = "White",
	GameOver = false,
	Winner = nil,
	GameState = "Normal",
	Mode = "ai", -- "ai" or "2p"
	SelectedPos = nil,
	CastlingRights = "KQkq",
	EnPassantTarget = nil,
	MoveHistory = {},
	WhiteTime = 600,
	BlackTime = 600,
	TimerRunning = false,
	LastTick = os.clock(),
	BoardParts = nil,
	PieceParts = {}
}

--===========================================================
-- MATCH SETTINGS (changed via UI buttons)
--===========================================================
local MatchSettings = {
	TimeMode = "Classic", -- "Classic" (10min) or "Bullet" (1min)
	AI_Difficulty = "Challenging", -- "Classic", "Challenging", "Monster"
}

local AI_Depths = { Classic = 1, Challenging = 2, Monster = 3 }
local NextDifficulty = { Classic = "Challenging", Challenging = "Monster", Monster = "Classic" }
local NextTimeMode = { Classic = "Bullet", Bullet = "Classic" }

function MatchSettings.GetTime()
	return MatchSettings.TimeMode == "Bullet" and 60 or 600
end

function MatchSettings.GetDepth()
	return AI_Depths[MatchSettings.AI_Difficulty] or 2
end

--===========================================================
-- BOARD GENERATOR
--===========================================================
local ts,ph=6,3
local boardOrigin = nil

function GetBoardOrigin()
	if boardOrigin then return boardOrigin end
	local char = Player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
		if root then
			local pos = root.Position
			boardOrigin = Vector3.new(pos.X - 4 * ts, pos.Y + 5, pos.Z + 20)
			return boardOrigin
		end
	end
	-- fallback: far away from game center to avoid conflicts
	boardOrigin = Vector3.new(500, 10, 500)
	return boardOrigin
end

function GenerateBoard()
	print("Chess loader: generating board...")
	local ex=Workspace:FindFirstChild("ChessBoard")
	if ex then ex:Destroy()end
	local ex2=Workspace:FindFirstChild("ChessPieces")
	if ex2 then ex2:Destroy()end

	local origin = GetBoardOrigin()
	local f=Instance.new("Folder")f.Name="ChessBoard";f.Parent=Workspace
	for x=1,8 do for y=1,8 do
		local t=Instance.new("Part")t.Size=Vector3.new(ts,1,ts)
		t.Position=origin + Vector3.new(x*ts,0,y*ts)
		t.Anchored=true;t.Name=x.."_"..y
		t.Color=(x+y)%2==0 and Color3.fromRGB(240,217,181)or Color3.fromRGB(181,136,99)
		t.Material=Enum.Material.SmoothPlastic;t.Parent=f
	end end
	Game.BoardParts=f
	Game.Origin=origin
	print("Chess loader: board generated at", origin)
end

function GetOrigin()
	return Game.Origin or Vector3.new(0,0,0)
end

function SyncPieces()
	local pf=Workspace:FindFirstChild("ChessPieces")
	if not pf then pf=Instance.new("Folder")pf.Name="ChessPieces";pf.Parent=Workspace end
	local tracked={}for _,p in ipairs(pf:GetChildren())do if p:IsA("Part")then local k=p:GetAttribute("X").."_"..p:GetAttribute("Y")tracked[k]=p end end
	local seen={}
	local origin=GetOrigin()
	for x=1,8 do for y=1,8 do
		local piece=Game.Board[x][y];local key=x.."_"..y;seen[key]=true
		if piece then
			local part=tracked[key]
			if not part then
				part=Instance.new("Part")part.Size=Vector3.new(ts*0.7,ph,ts*0.7);part.Anchored=true;part.Material=Enum.Material.SmoothPlastic;part:SetAttribute("X",x);part:SetAttribute("Y",y)
				local bg=Instance.new("BillboardGui")bg.Size=UDim2.new(2,0,2,0);bg.StudsOffset=Vector3.new(0,ph+1,0);bg.AlwaysOnTop=true
				local lbl=Instance.new("TextLabel")lbl.Size=UDim2.new(1,0,1,0);lbl.BackgroundTransparency=1;lbl.TextScaled=true;lbl.Font=Enum.Font.GothamBold;lbl.Parent=bg;bg.Parent=part;part.Parent=pf
			end
			part.Name=piece;part.Color=PieceData.PieceColors[piece]or Color3.fromRGB(128,128,128)
			part.Position=origin + Vector3.new(x*ts,ph/2,y*ts)
			local lbl=part:FindFirstChildOfClass("BillboardGui")and part:FindFirstChildOfClass("BillboardGui"):FindFirstChildOfClass("TextLabel")
			if lbl then lbl.Text=PieceData.PieceSymbols[piece]or "?";lbl.TextColor3=PieceData.PieceColors[piece]end
		end
	end end
	for k,p in pairs(tracked)do if not seen[k]then p:Destroy()end end
end

--===========================================================
-- GAME LOGIC
--===========================================================
function Game:ApplyMove(fx,fy,tx,ty)
	if self.GameOver then return false end
	if not Game.SelectedPos then return false end
	local piece=self.Board[fx][fy]if not piece then return false end
	local color=PieceData.GetColor(piece)
	if color~=self.Turn then return false end
	if self.Mode=="ai"and color=="Black"then return false end
	local valid,extra=ChessLogic.IsValidMove(self.Board,fx,fy,tx,ty,self.Turn,self.EnPassantTarget)
	if not valid then return false end
	local captured=self.Board[tx][ty]
	self.Board=ChessLogic.ApplyMove(self.Board,fx,fy,tx,ty)
	self:UpdateCastling(fx,fy,piece)
	self:UpdateEP(fx,fy,tx,ty,piece)
	table.insert(self.MoveHistory,{Piece=piece,From=string.char(96+fx)..fy,To=string.char(96+tx)..ty})
	self.Turn=self.Turn=="White"and"Black"or"White"
	local st,wn=ChessLogic.GetGameState(self.Board,self.Turn);self.GameState=st
	if st=="Checkmate"then self.GameOver=true;self.Winner=self.Turn=="White"and"Black"or"White"
	elseif st=="Stalemate"then self.GameOver=true;self.Winner="Draw"end
	SyncPieces()
	self:UpdateUI()
	if self.GameOver then self.TimerRunning=false;AI.TT={};return true end
	if self.Mode=="ai"and self.Turn=="Black"then self:DoAI()end
	return true
end
function Game:UpdateEP(fx,fy,tx,ty,p)self.EnPassantTarget=nil;if p and p:sub(2,2)=="P"and math.abs(ty-fy)==2 then self.EnPassantTarget={x=fx,y=(fy+ty)/2}end end
function Game:UpdateCastling(fx,fy,p)if not p then return end;local pt=p:sub(2,2)if pt=="K"then if PieceData.GetColor(p)=="White"then self.CastlingRights=self.CastlingRights:gsub("[KQ]","")else self.CastlingRights=self.CastlingRights:gsub("[kq]","")end elseif pt=="R"then if fx==1 and fy==1 then self.CastlingRights=self.CastlingRights:gsub("Q","")elseif fx==8 and fy==1 then self.CastlingRights=self.CastlingRights:gsub("K","")elseif fx==1 and fy==8 then self.CastlingRights=self.CastlingRights:gsub("q","")elseif fx==8 and fy==8 then self.CastlingRights=self.CastlingRights:gsub("k","")end end;if self.CastlingRights==""then self.CastlingRights="-"end end
function Game:GetValidMoves(x,y)local p=self.Board[x][y]if not p then return{}end;local c=PieceData.GetColor(p)if c~=self.Turn then return{}end;local m={}for tx=1,8 do for ty=1,8 do if x~=tx or y~=ty then local s=ChessLogic.IsValidMove(self.Board,x,y,tx,ty,c)if s then table.insert(m,{x=tx,y=ty})end end end end;return m end
function Game:DoAI()task.spawn(function()task.wait(0.3)if self.GameOver then return end;local m=AI.BestMove(self.Board,"Black")if m then self.SelectedPos={x=m.fx,y=m.fy};self:ApplyMove(m.fx,m.fy,m.tx,m.ty);self.SelectedPos=nil end end)end
function Game:StartTimer()
	self.TimerRunning=true;self.LastTick=os.clock()
	task.spawn(function()
		while not self.GameOver and self.TimerRunning do
			local now=os.clock();local dt=now-(self.LastTick or now);self.LastTick=now
			if self.Turn=="White"then self.WhiteTime=math.max(0,self.WhiteTime-dt)if self.WhiteTime<=0 then self.GameOver=true;self.Winner="Black";self.GameState="Timeout";self:UpdateUI();self.TimerRunning=false;return end
			else self.BlackTime=math.max(0,self.BlackTime-dt)if self.BlackTime<=0 then self.GameOver=true;self.Winner="White";self.GameState="Timeout";self:UpdateUI();self.TimerRunning=false;return end end
			self:UpdateUI()task.wait(0.5)
		end
	end)
end

--===========================================================
-- UI
--===========================================================
local sg=Instance.new("ScreenGui")sg.Name="ChessUI";sg.ResetOnSpawn=false;sg.Parent=PlayerGui
local highlights={}

local function clr()for _,h in ipairs(highlights)do pcall(function()h:Destroy()end)end;highlights={}end

local function mkLbl(pos,txt,color)
	local l=Instance.new("TextLabel")l.Size=UDim2.new(0,200,0,30);l.Position=pos;l.BackgroundTransparency=1;l.Text=txt;l.TextColor3=color or Color3.fromRGB(255,255,255);l.TextScaled=true;l.Font=Enum.Font.GothamBold;l.Parent=sg;return l
end
local function mkBtn(pos,txt,color,cb)
	local b=Instance.new("TextButton")b.Size=UDim2.new(0,200,0,50);b.Position=pos;b.BackgroundColor3=color or Color3.fromRGB(40,40,40);b.BackgroundTransparency=0.3;b.Text=txt;b.TextColor3=Color3.fromRGB(255,255,255);b.TextScaled=true;b.Font=Enum.Font.GothamBold;local c=Instance.new("UICorner")c.CornerRadius=UDim.new(0,8);c.Parent=b;b.MouseButton1Click:Connect(cb);b.Parent=sg;return b
end

local gi=mkLbl(UDim2.new(0.5,-100,0,10),"Chess")
local ti=mkLbl(UDim2.new(0.5,-100,0,40),"White's turn")
local wt=mkLbl(UDim2.new(0,20,0,10),"10:00")
local bt=mkLbl(UDim2.new(0,20,0,80),"10:00")

function Game:UpdateUI()
	ti.Text=self.Turn.."'s turn"
	local wm=math.floor(self.WhiteTime/60);local ws=math.floor(self.WhiteTime%60)
	wt.Text=string.format("%d:%02d",wm,ws);wt.TextColor3=self.WhiteTime<60 and Color3.fromRGB(255,50,50)or Color3.fromRGB(255,255,255)
	local bm=math.floor(self.BlackTime/60);local bs=math.floor(self.BlackTime%60)
	bt.Text=string.format("%d:%02d",bm,bs);bt.TextColor3=self.BlackTime<60 and Color3.fromRGB(255,50,50)or Color3.fromRGB(255,255,255)
	if self.GameState=="Check"then gi.Text="Check!";gi.TextColor3=Color3.fromRGB(255,200,0)
	elseif self.GameState=="Checkmate"then gi.Text="Checkmate! "..self.Winner.." wins!";gi.TextColor3=Color3.fromRGB(255,215,0)
	elseif self.GameState=="Stalemate"then gi.Text="Stalemate - Draw!";gi.TextColor3=Color3.fromRGB(200,200,200)
	elseif self.GameState=="Timeout"then gi.Text="Timeout! "..self.Winner.." wins!";gi.TextColor3=Color3.fromRGB(255,200,0)
	else gi.Text="Chess";gi.TextColor3=Color3.fromRGB(255,255,255)end
end

--===========================================================
-- INPUT
--===========================================================
UserInputService.InputBegan:Connect(function(input,gp)
	if gp then return end
	if input.UserInputType==Enum.UserInputType.MouseButton1 then
		local mouse=Player:GetMouse();local target=mouse.Target
		local board=Workspace:FindFirstChild("ChessBoard")
		if not target or not board then
			-- click on board parts only
			return
		end
		if target.Parent~=board then return end

		local xS,yS=target.Name:match("(%d+)_(%d+)")if not xS or not yS then return end
		local x,y=tonumber(xS),tonumber(yS)
		clr()

		if not Game.SelectedPos then
			local p=Game.Board[x][y]if p and PieceData.GetColor(p)==Game.Turn then
				Game.SelectedPos={x=x,y=y}
				local sel=Instance.new("SelectionBox")sel.Adornee=target;sel.Color3=Color3.fromRGB(255,255,0);sel.LineThickness=0.08;sel.Transparency=0.3;sel.Parent=target;table.insert(highlights,sel)
				local valid=Game:GetValidMoves(x,y)for _,m in ipairs(valid)do local mt=board:FindFirstChild(m.x.."_"..m.y)if mt then local h=Instance.new("SelectionBox")h.Adornee=mt;h.Color3=Color3.fromRGB(0,255,100);h.LineThickness=0.05;h.Transparency=0.5;h.Parent=mt;table.insert(highlights,h)end end
			end
		else
			local fx,fy=Game.SelectedPos.x,Game.SelectedPos.y;Game.SelectedPos=nil
			Game:ApplyMove(fx,fy,x,y)
		end
	end
end)

--===========================================================
-- BUTTONS
--===========================================================
local function StartGame(mode)
	local time = MatchSettings.GetTime()
	AI.Depth = MatchSettings.GetDepth()
	Game.Board=ChessLogic.NewBoard();Game.Turn="White";Game.GameOver=false;Game.Winner=nil;Game.GameState="Normal";Game.SelectedPos=nil;Game.CastlingRights="KQkq";Game.EnPassantTarget=nil;Game.MoveHistory={};Game.WhiteTime=time;Game.BlackTime=time;Game.TimerRunning=false;Game.Mode=mode;AI.TT={}
	clr();SyncPieces();Game:UpdateUI();Game:StartTimer()
end

local timeBtn = mkBtn(UDim2.new(0.5,-100,0,100), "Time: Classic", Color3.fromRGB(60,60,80), function()
	MatchSettings.TimeMode = NextTimeMode[MatchSettings.TimeMode]
	timeBtn.Text = "Time: " .. MatchSettings.TimeMode
end)

local diffBtn = mkBtn(UDim2.new(0.5,-100,0,170), "AI: Challenging", Color3.fromRGB(80,60,40), function()
	MatchSettings.AI_Difficulty = NextDifficulty[MatchSettings.AI_Difficulty]
	diffBtn.Text = "AI: " .. MatchSettings.AI_Difficulty
end)

mkBtn(UDim2.new(0.5,-100,0,240),"Play vs AI",Color3.fromRGB(40,80,40),function()
	StartGame("ai")
end)
mkBtn(UDim2.new(0.5,-100,0,310),"2-Player Hotseat",Color3.fromRGB(40,40,80),function()
	StartGame("2p")
end)
mkBtn(UDim2.new(0,20,0,200),"Teleport to Board",Color3.fromRGB(40,80,120),function()
	local origin=GetOrigin();local char=Player.Character
	if char then
		local root=char:FindFirstChild("HumanoidRootPart")or char:FindFirstChild("Torso")
		if root then root.CFrame=CFrame.new(origin + Vector3.new(4*ts,5, -4))end
	end
end)
mkBtn(UDim2.new(0,20,0,140),"Reset",Color3.fromRGB(120,40,40),function()
	local time = MatchSettings.GetTime()
	Game.Board=ChessLogic.NewBoard();Game.Turn="White";Game.GameOver=false;Game.Winner=nil;Game.GameState="Normal";Game.SelectedPos=nil;Game.CastlingRights="KQkq";Game.EnPassantTarget=nil;Game.MoveHistory={};Game.WhiteTime=time;Game.BlackTime=time;Game.TimerRunning=false;AI.TT={}
	clr();SyncPieces();Game:UpdateUI()
end)

--===========================================================
-- INIT
--===========================================================
print("Chess loader: initializing...")
GenerateBoard()
SyncPieces()
Game:UpdateUI()

print("=== CHESS GAME LOADED ===")
print("Click 'Time' to toggle Classic (10min) / Bullet (1min)")
print("Click 'AI' to cycle difficulty: Classic / Challenging / Monster")
print("Click 'Play vs AI' or '2-Player Hotseat' to start")
print("Click tiles to select and move pieces")
print("Use 'Teleport to Board' if you can't see the board")

-- Auto-repair: if game deletes our board, recreate it
task.spawn(function()
	while task.wait(3) do
		local boardExists = Workspace:FindFirstChild("ChessBoard")
		local piecesExist = Workspace:FindFirstChild("ChessPieces")
		if not boardExists or not piecesExist then
			print("Chess loader: board missing, regenerating...")
			boardOrigin = nil
			GenerateBoard()
			SyncPieces()
		end
	end
end)
