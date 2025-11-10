namespace LouveSystems.K2
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Text;
    using System.Threading.Tasks;
    using System.Drawing;
    using LouveSystems.K2.Lib;
    using System.IO;
    using LouveSystems.K2.BotLib;

    internal class Program
    {

        static readonly Dictionary<byte, ComputerPlayerBehaviour> personalities = new Dictionary<byte, ComputerPlayerBehaviour>();
        static int seed;

        static bool errorOccured = false;
        static bool makeCSV = true;
        static bool makePNG = true;
        static uint maxYieldDelayMs = 200;

        static int Main(string[] args)
        {
            Random random = new Random();
            seed = random.Next();

            List<string> remainingArgs = new List<string>(args);

            List<PartySessionInitializationParameters.RealmToInitialize> players = new List<PartySessionInitializationParameters.RealmToInitialize>();

            List<LuaFile> files = new List<LuaFile>();

            while (remainingArgs.Count > 0) {
                if (remainingArgs[0].Length > 1 && remainingArgs[0].StartsWith("/")) {
                    string val = remainingArgs[0].Substring(1).ToUpper();
                    remainingArgs.RemoveAt(0);
                    switch (val) {
                        case "LOG-K2LIB":
                            LouveSystems.K2.Lib.Logger.OnLog += (int level, object msg, string callerLocation)=>{
                                Console.WriteLine($"({level}) {msg}");
                            };

                            break;

                        case "TIMEOUT":
                            if (remainingArgs.Count > 0 && remainingArgs[0][0] != '/') {
                                maxYieldDelayMs = Convert.ToUInt32(remainingArgs[0]);
                                remainingArgs.RemoveAt(0);
                            }

                            break;

                        case "NOCAPTURE":
                            makePNG = false;
                            break;

                        case "NODUMP":
                            makeCSV = false;
                            break;


                        case "ADDPLAYER":
                            byte factionIndex = 0;

                            byte id = (byte)players.Count;

                            if (remainingArgs.Count > 0 && remainingArgs[0][0] != '/') {
                                factionIndex = Convert.ToByte(remainingArgs[0]);
                                remainingArgs.RemoveAt(0);
                            }

                            if (remainingArgs.Count > 0 && remainingArgs[0][0] != '/') {
                                string luaPath = remainingArgs[0];
                                remainingArgs.RemoveAt(0);

                                ScanSurroundings(luaPath, files, out int index);


                                try {
                                    personalities.Add(id, new LuaComputerPlayerBehaviour(index, files));
                                }
                                catch (Exception e) {
                                    Console.WriteLine(e);
                                    return 1;
                                }
                            }
                            else {
                                personalities.Add(id, new IdleComputerPlayerBehaviour());
                            }

                            players.Add(new PartySessionInitializationParameters.RealmToInitialize() {
                                factionIndex = factionIndex,
                                forPlayerId = id
                            });

                            break;
                    }
                }
            }

            if (players.Count <= 1) {
                Console.WriteLine("Not enough players - please use /addplayer <faction index> [<lua file path>] to add a personality.\nExamples:\n/addplayer 0\n/addplayer 0 example.lua");
                return 1;
            }

            GameRules rules = new GameRules();

            using (FileStream fs = File.OpenRead("DefaultRules.BIN")) {
                using (BinaryReader br = new BinaryReader(fs)) {
                    rules.Read(default, br);
                }
            }

            PartySessionInitializationParameters party = new PartySessionInitializationParameters(players.ToArray());
            
            GameSession session = new GameSession(party, rules, seed);

            // Max 100 steps
            DumpGamestate(session);

            for (int i = 0; i < 100; i++) {

                if (Advance(session)) {
                    DumpGamestate(session);
                }
                else {
                    break;
                }
            }

            if (errorOccured) {
                Console.WriteLine("=== ERROR OCCURED ===");
                return 1;
            }
            else {
                DumpGamestate(session);
                Console.WriteLine("=== DONE ===");
            }

            return 0;
        }

        private static void ScanSurroundings(string luaFilePath, in List<LuaFile> luaFiles, out int index)
        {
            luaFilePath = Path.GetFullPath(luaFilePath);
            var dir = Path.GetDirectoryName(luaFilePath);
            var files = Directory.GetFiles(dir, "*.lua", SearchOption.AllDirectories);
            index = default;

            foreach ( var file in files) {
                string localPath = file.Substring(dir.Length + 1);
                string fullPath = file;
                int i = luaFiles.FindIndex(o => o.name == localPath);
                if (i < 0) {
                    luaFiles.Add(new LuaFile(
                        name: Path.GetFileNameWithoutExtension(localPath),
                        getText: ()=>File.ReadAllText(fullPath)
                    ));

                    i = luaFiles.Count - 1;
                }

                if (fullPath == luaFilePath) {
                    index = i;
                }
            }

        }

        private static bool Advance(GameSession session)
        {
            try {
                DateTime initialTime = DateTime.Now;
                foreach (var b in personalities) {

                    DateTime chronometer = DateTime.Now;
                    var e = b.Value.TakeActions(b.Key, session);
                    while (e.MoveNext()) {
                        // continue
                        var delay = DateTime.Now - chronometer;

                        if (delay.TotalMilliseconds > maxYieldDelayMs) {
                            Console.WriteLine($"NOTICE: Interrupting by force personality {b} (took {((int)delay.TotalMilliseconds)}ms between two yields which is more than the allowed {maxYieldDelayMs}ms)");
                            break;
                        }

                        chronometer = DateTime.Now;
                    }

                    if ((DateTime.Now - initialTime).TotalSeconds > 30) {
                        Console.WriteLine($"NOTICE: Interrupting by force this turn because it's been more than 30 seconds ({(DateTime.Now - initialTime).TotalSeconds}))");
                        break;
                    }
                }

                // Fox time
                initialTime = DateTime.Now;
                foreach (var b in personalities) {

                    var sessionPlayer = session.SessionPlayers[b.Key];
                    if (sessionPlayer.Faction.HasFlagSafe(EFactionFlag.SeeEnemyPlannedConstructions)) {
                        DateTime chronometer = DateTime.Now;
                        var e = b.Value.TakeActionsLate(b.Key, session);
                        while (e.MoveNext()) {
                            // continue
                            var delay = DateTime.Now - chronometer;

                            if (delay.TotalMilliseconds > maxYieldDelayMs) {
                                Console.WriteLine($"NOTICE: Interrupting by force personality {b} (took {((int)delay.TotalMilliseconds)}ms between two yields which is more than the allowed {maxYieldDelayMs}ms)");
                                break;
                            }

                            chronometer = DateTime.Now;
                        }

                        if ((DateTime.Now - initialTime).TotalSeconds > 3) {
                            Console.WriteLine($"NOTICE: Interrupting by force this turn (late actions) because it's been more than 3 seconds ({(DateTime.Now - initialTime).TotalSeconds}))");
                            break;
                        }
                    }
                }
            }
            catch(Exception e) {
                Console.WriteLine(e.Message);
                errorOccured = true;
                return false;
            }

            return session.Advance();
        }

        private readonly struct CsvStatGetter
        {
            public readonly string name;
            public readonly Func<byte, string> getter;

            public CsvStatGetter(string name, Func<byte, string> getter)
            {
                this.name = name;
                this.getter = getter;
            }
        }

        private static void DumpGamestate(GameSession session)
        {
            string folder = seed.ToString();
            string day = $"day_{session.CurrentGameState.daysPassed}";

            Directory.CreateDirectory(folder);

            byte? getPlayerIndexFromRealm(byte realmIndex)
            {
                foreach(var kv in session.SessionPlayers) {
                    if (kv.Value.RealmIndex == realmIndex) {
                        return kv.Key;
                    }
                }

                return null;
            }

            // CSV
            if (makeCSV) {
                List<CsvStatGetter> getters = new List<CsvStatGetter>();
                getters.Add(new CsvStatGetter("realm", (realmIndex) => realmIndex.ToString()));
                getters.Add(new CsvStatGetter("personality", (realmIndex) =>
                {

                    byte? playerIndex = getPlayerIndexFromRealm(realmIndex);

                    if (playerIndex.HasValue) {
                        return personalities[playerIndex.Value].GetInternalName();
                    }

                    return "none";
                }));
                getters.Add(new CsvStatGetter("faction", (realmIndex) => session.CurrentGameState.world.GetRealmFaction(realmIndex).ToString()));
                getters.Add(new CsvStatGetter("treasury", (realmIndex) => (session.CurrentGameState.world.Realms[realmIndex].silverTreasury / 10f).ToString("n1")));
                getters.Add(new CsvStatGetter("maxDecisionCount", (realmIndex) => (session.CurrentGameState.world.Realms[realmIndex].availableDecisions / 10f).ToString("n1")));
                getters.Add(new CsvStatGetter("territory", (realmIndex) =>
                {
                    List<int> list = new List<int>();
                    session.CurrentGameState.world.GetTerritoryOfRealm(realmIndex, list);
                    return list.Count.ToString();
                }));

                var buildings = Enum.GetValues(typeof(EBuilding));
                for (int i = 0; i < buildings.Length; i++) {

                    EBuilding building = (EBuilding)buildings.GetValue(i);

                    if (building == EBuilding.Capital || building == EBuilding.None) {
                        continue;
                    }

                    getters.Add(new CsvStatGetter(building.ToString().ToLower(), (realmIndex) =>
                    {
                        int count = 0;
                        List<int> list = new List<int>();
                        session.CurrentGameState.world.GetTerritoryOfRealm(realmIndex, list);
                        for (int listIndex = 0; listIndex < list.Count; listIndex++) {
                            if (session.CurrentGameState.world.Regions[list[listIndex]].buildings == building) {
                                count++;
                            }
                        }

                        return count.ToString();
                    }));
                }

                getters.Add(new CsvStatGetter("favoured", (realmIndex) => session.CurrentGameState.world.Realms[realmIndex].isFavoured.ToString()));

                getters.Add(new CsvStatGetter("lastVotes", (realmIndex) =>
                {
                    if (session.CurrentGameState.voting.Result.scores == null) {
                        return "0";
                    }

                    var score = session.CurrentGameState.voting.Result.GetScoreOfRealm(realmIndex);
                    return score.totalVotes.ToString();
                }));

                List<string> values = new List<string>();


                using (FileStream fs = File.OpenWrite($"{folder}/{day}.CSV")) {
                    using (StreamWriter sw = new StreamWriter(fs)) {

                        values.Clear();
                        for (int getterIndex = 0; getterIndex < getters.Count; getterIndex++) {
                            values.Add(getters[getterIndex].name);
                        }

                        sw.WriteLine(string.Join("\t", values));
                        values.Clear();

                        for (byte realmIndex = 0; realmIndex < session.CurrentGameState.world.Realms.Count; realmIndex++) {

                            for (int getterIndex = 0; getterIndex < getters.Count; getterIndex++) {
                                values.Add(getters[getterIndex].getter(realmIndex));
                            }

                            sw.WriteLine(string.Join("\t", values));
                            values.Clear();
                        }
                    }
                }
            }

            if (makePNG) {
                using (FileStream fs = File.OpenWrite($"{folder}/{day}.PNG")) {
                    GameStateDrawer.Draw(session.CurrentGameState, out Bitmap bmp);
                    bmp.Save(fs, System.Drawing.Imaging.ImageFormat.Png);
                }
            }
        }
    }
}
