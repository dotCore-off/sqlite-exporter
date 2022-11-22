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

// Function - Fetch data contained in SQLite targetted table
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

// Function - Insert fetched data from SQLite database to remote database
function SQE.ExportMySQL(data)
    // Localize stuff cuz that doesn't hurt
    local table, string = table, string

    // Shouldn't happen but who knows
    if (!data or #data <= 0) then
        print("[SQLite Exporter] No data passed to the function, stopping.")
        return
    end

    // Shouldn't happen but who knows
    if (SQE.Database == nil) then
        SQE.InitializeConnection()
    end

    /*
        Create table in remote database if it doesn't exist yet
    */
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

    /*
        This will allows us to determine function to use based on each column expected value type
    */
    local columnNames, columnTypes, availableTypes = {}, {}, { "int", "string", "boolean", "varchar" }
    local function FetchColumnDetails(index, column)
        // Fetch column name
        local name = string.Explode(" ", column)
        columnNames[index] = name[1]

        // Fetch type per column and assign it
        for k, cType in ipairs(availableTypes) do
            local startPos = string.find(column, cType)
            if (startPos == nil) then continue end
            columnTypes[index] = cType
        end
    end

    for _, cms in ipairs(SQE.Config.Columns) do
        FetchColumnDetails(_, cms)
    end

    /*
        Formats a [k] = v table to an inline (v1, v2, v3) row that we can later use in an INSERT query as VALUES
        dataAsValues{} will contain all data formatted as bracket groups separated by a comma
    */
    local dataAsValues = {}
    local function FormatEndRow(row)
        // Initialize stuff we use
        // @pos represents the current column
        local tbl, pos = {}, 1

        // Loop through the non-numerical SQLite data and formats it as a numerical table
        for k, v in pairs(row) do
            if (SQE.Functions[columnTypes[pos]]) then
                v = SQE.Functions[columnTypes[pos]].convertFunc(v)
            end
            pos = pos + 1
            if (type(v) != "string") then
                table.insert(tbl, v)
                continue
            end
            v = "\'" .. v .. "\'"
            table.insert(tbl, v)
        end

        // Return created numerical table as a string - v1, v2, v3, etc..
        return table.concat(tbl, ", ")
    end

    for k, v in pairs(data) do
        // Needed to create bracket groups and insert multiple values
        local entry = { "(", ")," }
        local formattedRow = FormatEndRow(v)

        // Insert the values between (  ),
        table.insert(entry, 2, formattedRow)

        // This is needed so that we remove the , from last bracket group
        // If you don't do this, query will error as it expects another group of values to be added
        if (next(data, k) == nil) then entry[#entry] = ")" end

        // Insert into table containint all bracket groups
        table.insert(dataAsValues, table.concat(entry, " "))
    end

    /*
        FINAL STEP: Insert our formatted data into remote database, and print the status
    */
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

// Function - Starts connection to remote SQL database if Mysqloo module exists
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

// Launch the whole export process once all entities have been loaded
hook.Add("InitPostEntity", "SQE.LaunchExport", function()
    if (!SQE.Connected) then
        SQE.InitializeConnection()
    end
end)
