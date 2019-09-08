#include <lua.h>
#include <time.h>

static int
lua_tzset(lua_State *L)
{
    tzset();
    return 0;
}

int
luaopen_tzset(lua_State *L)
{
    lua_pushcfunction(L, lua_tzset);
    return 1;
}
