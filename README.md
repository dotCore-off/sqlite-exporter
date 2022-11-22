# 📟 SQLite Exporter 
An automatic and easy to use SQLite data exporter to remote database for Garry's Mod.

# 📃 How to use
1. [Download latest available release](https://github.com/dotCore-off/sqlite-exporter/releases)
2. **Unzip** and **open** file with a text / code editor
3. **Edit configuration** to match your needs
4. **Drag and drop the file** wherever you want as long as it is executed **serverside**
> `lua/autorun/server/` is fine for example

# ⚙️ It should work
- no matter the **amount of data** you're trying to retrieve and export
> tried with `million row' tables` and it worked fine
- no matter the **amount of columns provided**
- no matter the **column type provided**
> to be tested and confirmed

# ⚠️ Troubleshooting
- **What is mysqloo and where do I download it?**
> It is a **MySQL module** used to communicate with databases from Garry's Mod, you can [download it here](https://github.com/FredyH/MySQLOO)

- **It prints the INSERT query in console and doesn't export correctly**
> Please, ensure that **column order is correct** in SQE.Config.Columns.  
> You can print fetched `data from SQLite` to see the order to use

- **It seems that data in my database are duped**
> Script probably executed twice or more *(which shouldn't happen except if you change map / reboot)*.  
> `TRUNCATE` or `DROP` table and execute the script again
