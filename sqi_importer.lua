// DO NOT TOUCH OR FILE WILL BREAK
SQI = SQI or {}
SQI.Config = SQI.Config or {}
SQI.Connected = false
SQI.Functions = {
    ["string"] = {
        convertFunC = function(arg)
            return !isstring(arg) and tostring(arg) or arg
        end
    },
    ["int"] = {
        convertFunc = function(arg)
            return !isnumber(arg) and tonumber(arg) or arg
        end
    },
    ["boolean"] = {
        convertFunc = function(arg)
            return !isbool(arg) and tobool(arg) or arg
        end
    },
    ["varchar"] = {
        convertFunc = function(arg)
            return !isstring(arg) and tostring(arg) or arg
        end
    }
}
require("mysqloo")
// DO NOT TOUCH OR FILE WILL BREAK

/*
    SQLite Importer - Config
*/

// MySQL database credentials goes here
SQI.Config.SqlInfos = {
    ["hostname"] = "",
    ["username"] = "",
    ["password"] = "",
    ["database"] = "",
    ["port"] = 3306
}

// Table to target - string
SQI.Config.Table = ""

// Columns to use when creating table - table of string
SQI.Config.Columns = {
    // Example: "amount int",
    // Example: "steamID64 varchar(20) NOT NULL",
}

// Specific condition to use when fetching data from SQLite - false or string
SQI.Config.Condition = ""

/*
    SQLiter Importer - End of config
*/


/*
    MAIN LOGIC
*/

function SQI.FetchSQLite()
    if (!isstring(SQI.Config.Table) or #SQI.Config.Table <= 0) then
        print("[SQLite Importer] Please, indicate a valid table to target!")
        return
    end

    if (!SQI.Config.Condition) then
        print("[SQLite Importer] No condition were given, proceeding.")
    end

    local fetchQuery = sql.Query("SELECT * FROM " .. SQI.Config.Table .. " " .. (SQI.Config.Condition or "") .. ";")
    if (!fetchQuery) then
        print("[SQLite Importer] ERROR", sql.LastError())
        return
    else
        print("[SQLite Importer] Fetched " .. SQI.Config.Table .. " table correctly, " .. #fetchQuery .. " rows received, processing..")
        SQI.ImportMySQL(fetchQuery)
    end
end

function SQI.ImportMySQL(data)
    local table, string = table, string

    if (!data or #data <= 0) then
        print("[SQLite Importer] No data passed to the function, stopping.")
        return
    end

    if (SQI.Database == nil) then
        SQI.InitializeConnection()
    end

    local createQuery = SQI.Database:query([[ CREATE TABLE IF NOT EXISTS ]] .. SQI.Config.Table .. [[ ( ]]
    .. table.concat(SQI.Config.Columns, ", ") ..
    [[ ) ]])

    function createQuery:onError(q, err)
        print("[SQLite Importer] " .. err)
        return
    end

    function createQuery:onSuccess()
        print("[SQLite Importer] Successfully created " .. SQI.Config.Table .. " table!")
    end
    createQuery:start()

    local columnNames, columnTypes, availableTypes = {}, {}, { "int", "string", "boolean", "varchar" }
    for _, cms in ipairs(SQI.Config.Columns) do
        local name = string.Explode(" ", cms)
        columnNames[_] = name[1]
        for k, tpe in ipairs(availableTypes) do
            local startPos = string.find(cms, tpe)
            if (startPos == nil) then continue end
            columnTypes[_] = tpe
        end
    end

    local dataAsValues = {}
    for k, v in pairs(data) do
        local entry, tbl, pos = { "(", ")," }, { }, 1
        for index, value in pairs(v) do
            if (SQI.Functions[columnTypes[pos]]) then
                value = SQI.Functions[columnTypes[pos]].convertFunc(value)
            end
            pos = pos + 1
            if (type(value) != "string") then
                table.insert(tbl, value)
                continue
            end
            value = "\'" .. value .. "\'"
            table.insert(tbl, value)
        end
        table.insert(entry, 2, table.concat(tbl, ", "))
        if (next(data, k) == nil) then entry[#entry] = ")" end
        table.insert(dataAsValues, table.concat(entry, " "))
    end

    local insertQuery = SQI.Database:query("INSERT INTO " .. SQI.Config.Table .. "(" .. table.concat(columnNames, ", ") .. ") VALUES " .. table.concat(dataAsValues, "") .. ";")

    function insertQuery:onSuccess()
        print("[SQLite Importer] Import is done, you can remove the file now!")
    end

    function insertQuery:onError(q, err)
        print("[SQLite Importer] " .. err)
        return
    end
    insertQuery:start()
end

function SQI.InitializeConnection()
    if (!mysqloo) then
        return print("[SQLite Importer] ERROR: make sure that mysqloo module is properly installed.")
    end

    SQI.Database = mysqloo.connect(SQI.Config.SqlInfos["hostname"], SQI.Config.SqlInfos["username"], SQI.Config.SqlInfos["password"], SQI.Config.SqlInfos["database"], { ["port"] = SQI.Config.SqlInfos["port"] })

    function SQI.Database:onConnected()
        print("[SQLite Importer] Connected to MySQL database!")
        SQI.Connected = true
        SQI.FetchSQLite()
    end

    function SQI.Database:onConnectionFailed(err)
        print("[SQL Importer] Cannot connect to database:\n" .. err)
        return
    end

    SQI.Database:connect()
end

hook.Add("InitPostEntity", "SQI.LaunchImport", function()
    if (!SQI.Connected) then
        SQI.InitializeConnection()
    end
end)
