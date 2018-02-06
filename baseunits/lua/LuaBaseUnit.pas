unit LuaBaseUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, lua53, uBaseUnit;

procedure luaBaseUnitRegister(L: Plua_State);

implementation

uses
  LuaUtils, MultiLog;

function lua_pos(L: Plua_State): Integer; cdecl;
begin
  lua_pushinteger(L, Pos(lua_tostring(L, 1), lua_tostring(L, 2)));
  Result := 1;
end;

function lua_trim(L: Plua_State): Integer; cdecl;
begin
  lua_pushstring(L, Trim(lua_tostring(L, 1)));
  Result := 1;
end;

function lua_maybefillhost(L: Plua_State): Integer; cdecl;
begin
  lua_pushstring(L, MaybeFillHost(lua_tostring(L, 1), lua_tostring(L, 2)));
  Result := 1;
end;

function lua_invertstrings(L: Plua_State): Integer; cdecl;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to lua_gettop(L) do
    InvertStrings(TStringList(luaGetUserData(L, i)));
end;

function lua_mangainfostatusifpos(L: Plua_State): Integer; cdecl;
begin
  case lua_gettop(L) of
    3: lua_pushstring(L, MangaInfoStatusIfPos(lua_tostring(L, 1),
        lua_tostring(L, 2), lua_tostring(L, 3)));
    2: lua_pushstring(L, MangaInfoStatusIfPos(lua_tostring(L, 1), lua_tostring(L, 2)));
    1: lua_pushstring(L, MangaInfoStatusIfPos(lua_tostring(L, 1)));
    else
      Exit(0);
  end;
  Result := 1;
end;

procedure luaBaseUnitRegister(L: Plua_State);
begin
  luaPushFunctionGlobal(L, 'Pos', @lua_pos);
  luaPushFunctionGlobal(L, 'Trim', @lua_trim);
  luaPushFunctionGlobal(L, 'MaybeFillHost', @lua_maybefillhost);
  luaPushFunctionGlobal(L, 'InvertStrings', @lua_invertstrings);
  luaPushFunctionGlobal(L, 'MangaInfoStatusIfPos', @lua_mangainfostatusifpos);
end;

end.
