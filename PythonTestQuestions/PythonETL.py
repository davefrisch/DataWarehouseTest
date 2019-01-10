import os
import pandas
import pyodbc 

directory = "C:\\OneDrive\Work\Stage"
for filename in os.listdir(directory):
    if filename.endswith(".xlsx"): 
        fileDirectoryPath = (os.path.join(directory, filename))
        fileNameWOExtension = os.path.splitext(filename)[0]
        fileDate = ('20' + fileNameWOExtension[-2:] + '-' + fileNameWOExtension[-6:-4] + '-' + fileNameWOExtension[-4:-2])
        medicalGroup = fileNameWOExtension[:-7]

        path = fileDirectoryPath
        df = pandas.read_excel(io=path,sheet_name=0,skiprows=3)
        # print(df.head(5))

        df = df.rename(columns={df.columns[1]: 'SourceId',
                                df.columns[2]: 'FirstName',
                                df.columns[3]: 'MiddleName',
                                df.columns[4]: 'LastName',
                                df.columns[5]: 'DateOfBirth',
                                df.columns[6]: 'Sex',
                                df.columns[7]: 'FavoriteColor',
                                df.columns[8]: 'AttributedQ1',
                                df.columns[9]: 'AttributedQ2',
                                df.columns[10]: 'RiskQ1',
                                df.columns[11]: 'RiskQ2',
                                df.columns[12]: 'RiskIncreasedFlag',
                                })
        df=df.drop(df.columns[0], axis=1)
        df = df.fillna('')
        # print(df.head(5))

        for index, row in df.iterrows():
            if pandas.isnull(row["SourceId"]) == False and (str.isdigit(row["SourceId"]) == True):
                # print(row["SourceId"], row["FirstName"], row["MiddleName"], row["LastName"], row["DateOfBirth"], row["Sex"], row["FavoriteColor"], medicalGroup, fileDate)
                # print(row["SourceId"],row["AttributedQ1"],row["AttributedQ2"],row["RiskQ1"],row["RiskQ2"],row["RiskIncreasedFlag"], medicalGroup, fileDate)

                connection = pyodbc.connect('Driver={SQL Server Native Client 11.0};Server=DF-LPTP-HP360X;Database=PersonDatabase;Trusted_Connection=yes;') 
                cursor = connection.cursor() 
                SQLCommand = ("INSERT INTO Stage.GroupDemographics"
                                "(SourceId, FirstName, MiddleName, LastName, DateOfBirth, Sex, FavoriteColor, GroupName, Date)"
                                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
                Values = [row["SourceId"],row["FirstName"],row["MiddleName"][0:1],row["LastName"],str(row["DateOfBirth"])[0:23],str(row["Sex"]).replace("1.0","F").replace("0.0","M"),row["FavoriteColor"], medicalGroup, fileDate]
                cursor.execute(SQLCommand,Values)

                if row["RiskIncreasedFlag"] == "Yes" :
                    SQLCommand = ("INSERT INTO Stage.QuartersRisk"
                                    "(SourceId, Quarter, AttributedFlag, RiskScore, GroupName, Date)"
                                    "VALUES (?, ?, ?, ?, ?, ?)")
                    Values = [row["SourceId"],"Q1",row["AttributedQ1"][0:1],row["RiskQ1"], medicalGroup, fileDate]
                    cursor.execute(SQLCommand,Values)

                    SQLCommand = ("INSERT INTO Stage.QuartersRisk"
                                    "(SourceId, Quarter, AttributedFlag, RiskScore, GroupName, Date)"
                                    "VALUES (?, ?, ?, ?, ?, ?)")
                    Values = [row["SourceId"],"Q2",row["AttributedQ2"][0:1],row["RiskQ2"], medicalGroup, fileDate]
                    cursor.execute(SQLCommand,Values)

                cursor.execute(SQLCommand,Values)
                connection.commit()
                connection.close()

