// DO NOT TOUCH OR FILE WILL BREAK
SQE = SQE or {}
SQE.Config = SQE.Config or {}
SQE.Connected = false
SQE.Functions = {
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
    SQLite Exporter - Config
*/

// MySQL database credentials goes here
SQE.Config.SqlInfos = {
    ["hostname"] = "",
    ["username"] = "",
    ["password"] = "",
    ["database"] = "",
    ["port"] = 3306
}

// Table to target - string
SQE.Config.Table = ""

// Columns to use when creating table - table of string
SQE.Config.Columns = {
    // Example: "amount int",
    // Example: "steamID64 varchar(20) NOT NULL",
}

// Specific condition to use when fetching data from SQLite - false or string
SQE.Config.Condition = ""

/*
    SQLiter Exporter - End of config
*/


/*
    MAIN LOGIC
*/

function SQE.FetchSQLite()
    if (!isstring(SQE.Config.Table) or #SQE.Config.Table <= 0) then
        print("[SQLite Exporter] Please, indicate a valid table to target!")
        return
    end

    if (!SQE.Config.Condition) then
        print("[SQLite Exporter] No condition were given, proceeding.")
    end

    local fetchQuery = sql.Query("SELECT * FROM " .. SQE.Config.Table .. " " .. (SQE.Config.Condition or "") .. ";")
    if (!fetchQuery) then
        print("[SQLite Exporter] ERROR", sql.LastError())
        return
    else
        print("[SQLite Exporter] Fetched " .. SQE.Config.Table .. " table correctly, " .. #fetchQuery .. " rows received, processing..")
        SQE.ExportMySQL(fetchQuery)
    end
end

function SQE.ExportMySQL(data)
    local table, string = table, string

    if (!data or #data <= 0) then
        print("[SQLite Exporter] No data passed to the function, stopping.")
        return
    end

    if (SQE.Database == nil) then
        SQE.InitializeConnection()
    end

    local createQuery = SQE.Database:query([[ CREATE TABLE IF NOT EXISTS ]] .. SQE.Config.Table .. [[ ( ]]
    .. table.concat(SQE.Config.Columns, ", ") ..
    [[ ) ]])

    function createQuery:onError(q, err)
        print("[SQLite Exporter] " .. err)
        return
    end

    function createQuery:onSuccess()
        print("[SQLite Exporter] Successfully created " .. SQE.Config.Table .. " table!")
    end
    createQuery:start()

    local columnNames, columnTypes, availableTypes = {}, {}, { "int", "string", "boolean", "varchar" }
    for _, cms in ipairs(SQE.Config.Columns) do
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
            if (SQE.Functions[columnTypes[pos]]) then
                value = SQE.Functions[columnTypes[pos]].convertFunc(value)
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

    local insertQuery = SQE.Database:query("INSERT INTO " .. SQE.Config.Table .. "(" .. table.concat(columnNames, ", ") .. ") VALUES " .. table.concat(dataAsValues, "") .. ";")

    function insertQuery:onSuccess()
        print("[SQLite Exporter] Export is done, you can remove the file now!")
    end

    function insertQuery:onError(q, err)
        print("[SQLite Exporter] " .. err)
        return
    end
    insertQuery:start()
end

function SQE.InitializeConnection()
    if (!mysqloo) then
        return print("[SQLite Exporter] ERROR: make sure that mysqloo module is properly installed.")
    end

    SQE.Database = mysqloo.connect(SQE.Config.SqlInfos["hostname"], SQE.Config.SqlInfos["username"], SQE.Config.SqlInfos["password"], SQE.Config.SqlInfos["database"], { ["port"] = SQE.Config.SqlInfos["port"] })

    function SQE.Database:onConnected()
        print("[SQLite Exporter] Connected to MySQL database!")
        SQE.Connected = true
        SQE.FetchSQLite()
    end

    function SQE.Database:onConnectionFailed(err)
        print("[SQL Exporter] Cannot connect to database:\n" .. err)
        return
    end

    SQE.Database:connect()
end

hook.Add("InitPostEntity", "SQE.LaunchExport", function()
    if (!SQE.Connected) then
        SQE.InitializeConnection()
    end
end)
