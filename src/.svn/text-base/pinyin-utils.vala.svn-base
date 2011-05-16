/******************************************************************************
 *  ibus-cloud-pinyin - cloud pinyin client for ibus
 *  Copyright (C) 2010 WU Jun <quark@lihdd.net>
 *
 * 
 *  This file is part of ibus-cloud-pinyin.
 *
 *  ibus-cloud-pinyin is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  ibus-cloud-pinyin is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with ibus-cloud-pinyin.  If not, see <http://www.gnu.org/licenses/>.
 *****************************************************************************/

using Gee;

namespace icp {
  namespace Pinyin {
    HashSet<string> valid_partial_pinyins;
    HashSet<string> valid_pinyins;

    HashMap<string, int> consonant_ids;
    HashMap<string, int> vowel_ids;

    HashMap<int, string> consonant_reverse_ids;
    HashMap<int, string> vowel_reverse_ids;

    // adjustments for pinyin default cutting
    // length: 4 to 8
    HashMap<string, string> cutting_adjusts;

    public class Id {
      public int consonant { get; private set; }
      public int vowel { get; private set; }

      public Id.pinyin(string? pinyin) {
        if (pinyin == null) {
          consonant = 0;
          vowel = -1;
          return;
        }

        string vowel_str;
        if (pinyin.length > 1 && consonant_ids.has_key(pinyin[0:2])) {
          consonant = consonant_ids[pinyin[0:2]];
          vowel_str = pinyin[2:pinyin.length];
        } else if (pinyin.length > 0 && consonant_ids.has_key(pinyin[0:1])) {
          consonant = consonant_ids[pinyin[0:1]];
          vowel_str = pinyin[1:pinyin.length];
        } else {
          consonant = 0;
          vowel_str = pinyin;
        }
        if (vowel_ids.has_key(vowel_str) && (pinyin in valid_pinyins)) {
          vowel = vowel_ids[vowel_str];
        } else vowel = -1;
      }

      public Id.id(int cid = 0, int vid = -1) {
        consonant = cid;
        vowel = vid;
      }

      public Id(string? pinyin = null) {
        this.pinyin(pinyin);
      }

      public bool empty() {
        return (consonant <= 0 && vowel <= 0);
      }

      public string to_string() {
        if (empty()) return "";
        // special treat lüe nüe
        return consonant_reverse_ids[consonant]
          + (((consonant == 10 || consonant == 12) && vowel == 52)
          ? "üe" : vowel_reverse_ids[vowel]);
      }

      public static uint hash_func(Id a) {
        return (uint)(a.consonant * 128 + a.vowel);
      }

      public static bool equal_func(Id a, Id b) {
        return a.consonant == b.consonant && a.vowel == b.vowel;
      }
    }

    public class Sequence {
      private ArrayList<Id> id_sequence;

      private static bool is_valid_pinyin_begin(string pinyins, 
          int start, int len_max) {
        // used by Sequence string parser
        if (pinyins.length <= start) return true;
        if (pinyins[start] > 'z' || pinyins[start] < 'a') return true;
        for (int i = 1; i <= len_max && i + start <= pinyins.length; i++) {
          if (!valid_partial_pinyins.contains(pinyins[start:start+i]))
            return false;
        }
        return true;
      }

      public void clear() {
        id_sequence.clear();
      }

      public Sequence(string? pinyins = null) {
        this.pinyins(pinyins);
      }

      public Sequence.pinyins(string? pinyins = null) {
        id_sequence = new ArrayList<Id>();

        if (pinyins == null) return;

        // construct by pinyins string
        string pinyins_pre;
        try {
          pinyins_pre = /__+/.replace(
              /[^a-z]/.replace(pinyins, -1, 0, "_"), -1, 0, "_"
              );
        } catch (RegexError e) {
          pinyins_pre = "";
        }

        for (int pos = 0; pos < pinyins_pre.length;) {
          int len = 0;
          // consider adjusted cuttings
          for (int l = 8; l >= 4; l--) {
            if (l + pos <= pinyins_pre.length 
                && cutting_adjusts.has_key(pinyins_pre[pos:pos+l])) {
              // recheck, do not break following pinyins
              if (!is_valid_pinyin_begin(pinyins_pre, pos + l, 2)) continue;
              // use selected adjusted cutting
              var pinyin_splited
                = cutting_adjusts[pinyins_pre[pos:pos+l]].split(" ");
              foreach (string pinyin_item in pinyin_splited) {
                Id id = new Id(pinyin_item);
                if (!id.empty()) id_sequence.add(new Id(pinyin_item));
              }
              len = l;
              break;
            }
          }

          // standard one pinyin cutting
          if (len == 0)
            for (len = 6; len > 0; len--) {
              if (pos + len <= pinyins_pre.length) {
                if (pinyins_pre[pos:pos + len] in valid_partial_pinyins) {
                  // consider one step futher if len > 1
                  if (len > 1 && !is_valid_pinyin_begin(
                        pinyins_pre, pos + len, 1
                        )) continue;
                Id id = new Id(pinyins_pre[pos:pos + len]);
                 if (!id.empty()) id_sequence.add(id);
                  break;
                }
              }
            }

          if (len == 0) {
            // invalid, skip it
            pos++;
          } else {
            pos += len;
          }
        } // for pos
      }

      public Sequence.ids(ArrayList<Id>? ids = null) {
        id_sequence = new ArrayList<Id>();

        if (ids == null) return;

        // construct by ids arraylist
        foreach (Id id in ids) {
          if (consonant_reverse_ids.has_key(id.consonant)
              && vowel_reverse_ids.has_key(id.vowel)) {
            id_sequence.add(id);
          }
        }
      }

      public Sequence.copy(Sequence that, int start = 0, int len = -1) {
        id_sequence = new ArrayList<Id>();

        while (start < 0) start = start + that.size;
        while (len < 0) len = that.size;

        int end = start + len;
        if (end > that.size) end = that.size;

        for (int i = start; i < end; i++)
          id_sequence.add(that.get_id(i));
      }

      public string to_string(int start = 0, int len = -1) {
        while (start < 0) start = start + id_sequence.size;
        while (len < 0) len = id_sequence.size;

        int end = start + len;
        if (end > id_sequence.size) end = id_sequence.size;

        var builder = new StringBuilder();
        for (int i = start; i < end; i++) {
          if (i > start) builder.append(" ");
          builder.append(get(i));
        }

        return builder.str;
      }

      public string to_double_pinyin_string(int start = 0, int len = -1) {
        while (start < 0) start = start + id_sequence.size;
        while (len < 0) len = id_sequence.size;

        int end = start + len;
        if (end > id_sequence.size) end = id_sequence.size;

        var builder = new StringBuilder();
        for (int i = start; i < end; i++) {
          builder.append(DoublePinyin.lookup(id_sequence.get(i)));
        }

        return builder.str;
      }

      public string get(int index) {
        if (index < 0 || index > id_sequence.size) return "";
        return id_sequence.get(index).to_string();
      }

      public Id get_id(int index) {
        if (index < 0 || index > id_sequence.size) return new Id("");
        return id_sequence.get(index);
      }

      public int size {
        get {
          return id_sequence.size;
        }
      }
    }

    public class DoublePinyin {
      private static HashMap<Id, string> reverse_scheme;
      private static HashMap<string, Id> scheme;
      private static HashSet<uint> valid_keys;

      private DoublePinyin() { }

      public static void init() {
        reverse_scheme = new HashMap<Id, string>((HashFunc)Id.hash_func, (EqualFunc)Id.equal_func);
        scheme = new HashMap<string, Id>();
        valid_keys = new HashSet<uint>();
      }

      public static void clear() {
        valid_keys.clear();
        scheme.clear();
      }

      public static bool is_valid_key(uint key) {
        return (key in valid_keys);
      }

      public static void insert(string double_pinyin, string pinyin) {
        switch (double_pinyin.length) {
          case 1:
            Id id = new Id(pinyin);
            if (id.consonant > 0 && id.vowel == -1) {
              // valid
              scheme[double_pinyin] = id;
              reverse_scheme[id] = double_pinyin;
              valid_keys.add((uint)double_pinyin[0]);
            }
            break;
          case 2:
            if (pinyin in valid_pinyins) {
              Id id = new Id(pinyin);
              if (!id.empty()) {
                // valid
                scheme[double_pinyin] = id;
                reverse_scheme[id] = double_pinyin;
                valid_keys.add((uint)double_pinyin[0]);
                valid_keys.add((uint)double_pinyin[1]);
              }
            }
            break;
        }
      }

      // convert to pinyin sequence
      public static void convert(string double_pinyins, 
          out Sequence sequence) {
        ArrayList<Id> ids = new ArrayList<Id>();
        for (int pos = 0; pos < double_pinyins.length; ++pos) {
          if (pos + 1 < double_pinyins.length) {
            if (scheme.has_key(double_pinyins[pos:pos+2])) {
              ids.add(scheme[double_pinyins[pos:pos+2]]);
              pos++;
            }
          } else {
            // last char
            string s = double_pinyins[pos:pos+1];
            Id id = scheme.has_key(s) ? scheme[s] : new Id(s);
            if (!id.empty()) ids.add(new Id.id(id.consonant, -1));
          }
        }
        sequence = new Sequence.ids(ids);
      }

      // convert Id to double_pinyin
      public static string lookup(Id id) {
        if (reverse_scheme.has_key(id)) return reverse_scheme[id];
        else return "";
      }
    }

    static void init() {
      valid_pinyins = new HashSet<string>();
      valid_partial_pinyins = new HashSet<string>();

      // hardcoded valid pinyins
      valid_pinyins.add("ba");
      valid_pinyins.add("bai");
      valid_pinyins.add("ban");
      valid_pinyins.add("bang");
      valid_pinyins.add("bao");
      valid_pinyins.add("bei");
      valid_pinyins.add("ben");
      valid_pinyins.add("beng");
      valid_pinyins.add("bi");
      valid_pinyins.add("bian");
      valid_pinyins.add("biao");
      valid_pinyins.add("bie");
      valid_pinyins.add("bin");
      valid_pinyins.add("bing");
      valid_pinyins.add("bo");
      valid_pinyins.add("bu");
      valid_pinyins.add("ca");
      valid_pinyins.add("cai");
      valid_pinyins.add("can");
      valid_pinyins.add("cang");
      valid_pinyins.add("cao");
      valid_pinyins.add("ce");
      valid_pinyins.add("cen");
      valid_pinyins.add("ceng");
      valid_pinyins.add("cha");
      valid_pinyins.add("chai");
      valid_pinyins.add("chan");
      valid_pinyins.add("chang");
      valid_pinyins.add("chao");
      valid_pinyins.add("che");
      valid_pinyins.add("chen");
      valid_pinyins.add("cheng");
      valid_pinyins.add("chi");
      valid_pinyins.add("chong");
      valid_pinyins.add("chou");
      valid_pinyins.add("chu");
      valid_pinyins.add("chuai");
      valid_pinyins.add("chuan");
      valid_pinyins.add("chuang");
      valid_pinyins.add("chui");
      valid_pinyins.add("chun");
      valid_pinyins.add("chuo");
      valid_pinyins.add("ci");
      valid_pinyins.add("cong");
      valid_pinyins.add("cou");
      valid_pinyins.add("cu");
      valid_pinyins.add("cuan");
      valid_pinyins.add("cui");
      valid_pinyins.add("cun");
      valid_pinyins.add("cuo");
      valid_pinyins.add("da");
      valid_pinyins.add("dai");
      valid_pinyins.add("dan");
      valid_pinyins.add("dang");
      valid_pinyins.add("dao");
      valid_pinyins.add("de");
      valid_pinyins.add("dei");
      valid_pinyins.add("deng");
      valid_pinyins.add("di");
      valid_pinyins.add("dian");
      valid_pinyins.add("diao");
      valid_pinyins.add("die");
      valid_pinyins.add("ding");
      valid_pinyins.add("diu");
      valid_pinyins.add("dong");
      valid_pinyins.add("dou");
      valid_pinyins.add("du");
      valid_pinyins.add("duan");
      valid_pinyins.add("dui");
      valid_pinyins.add("dun");
      valid_pinyins.add("duo");
      valid_pinyins.add("fa");
      valid_pinyins.add("fan");
      valid_pinyins.add("fang");
      valid_pinyins.add("fei");
      valid_pinyins.add("fen");
      valid_pinyins.add("feng");
      valid_pinyins.add("fo");
      valid_pinyins.add("fou");
      valid_pinyins.add("fu");
      valid_pinyins.add("ga");
      valid_pinyins.add("gai");
      valid_pinyins.add("gan");
      valid_pinyins.add("gang");
      valid_pinyins.add("gao");
      valid_pinyins.add("ge");
      valid_pinyins.add("gei");
      valid_pinyins.add("gen");
      valid_pinyins.add("geng");
      valid_pinyins.add("gong");
      valid_pinyins.add("gou");
      valid_pinyins.add("gu");
      valid_pinyins.add("gua");
      valid_pinyins.add("guai");
      valid_pinyins.add("guan");
      valid_pinyins.add("guang");
      valid_pinyins.add("gui");
      valid_pinyins.add("gun");
      valid_pinyins.add("guo");
      valid_pinyins.add("ha");
      valid_pinyins.add("hai");
      valid_pinyins.add("han");
      valid_pinyins.add("hang");
      valid_pinyins.add("hao");
      valid_pinyins.add("he");
      valid_pinyins.add("hei");
      valid_pinyins.add("hen");
      valid_pinyins.add("heng");
      valid_pinyins.add("hong");
      valid_pinyins.add("hou");
      valid_pinyins.add("hu");
      valid_pinyins.add("hua");
      valid_pinyins.add("huai");
      valid_pinyins.add("huan");
      valid_pinyins.add("huang");
      valid_pinyins.add("hui");
      valid_pinyins.add("hun");
      valid_pinyins.add("huo");
      valid_pinyins.add("ji");
      valid_pinyins.add("jia");
      valid_pinyins.add("jian");
      valid_pinyins.add("jiang");
      valid_pinyins.add("jiao");
      valid_pinyins.add("jie");
      valid_pinyins.add("jin");
      valid_pinyins.add("jing");
      valid_pinyins.add("jiong");
      valid_pinyins.add("jiu");
      valid_pinyins.add("ju");
      valid_pinyins.add("juan");
      valid_pinyins.add("jue");
      valid_pinyins.add("jun");
      valid_pinyins.add("ka");
      valid_pinyins.add("kai");
      valid_pinyins.add("kan");
      valid_pinyins.add("kang");
      valid_pinyins.add("kao");
      valid_pinyins.add("ke");
      valid_pinyins.add("ken");
      valid_pinyins.add("keng");
      valid_pinyins.add("kong");
      valid_pinyins.add("kou");
      valid_pinyins.add("ku");
      valid_pinyins.add("kua");
      valid_pinyins.add("kuai");
      valid_pinyins.add("kuan");
      valid_pinyins.add("kuang");
      valid_pinyins.add("kui");
      valid_pinyins.add("kun");
      valid_pinyins.add("kuo");
      valid_pinyins.add("la");
      valid_pinyins.add("lai");
      valid_pinyins.add("lan");
      valid_pinyins.add("lang");
      valid_pinyins.add("lao");
      valid_pinyins.add("le");
      valid_pinyins.add("lei");
      valid_pinyins.add("leng");
      valid_pinyins.add("li");
      valid_pinyins.add("lian");
      valid_pinyins.add("liang");
      valid_pinyins.add("liao");
      valid_pinyins.add("lie");
      valid_pinyins.add("lin");
      valid_pinyins.add("ling");
      valid_pinyins.add("liu");
      valid_pinyins.add("long");
      valid_pinyins.add("lou");
      valid_pinyins.add("lu");
      valid_pinyins.add("luan");
      // valid_pinyins.add("lue"); // not standard
      valid_pinyins.add("lun");
      valid_pinyins.add("luo");
      valid_pinyins.add("lv");
      valid_pinyins.add("lü");
      valid_pinyins.add("lve");
      valid_pinyins.add("lüe");
      valid_pinyins.add("ma");
      valid_pinyins.add("mai");
      valid_pinyins.add("man");
      valid_pinyins.add("mang");
      valid_pinyins.add("mao");
      valid_pinyins.add("me");
      valid_pinyins.add("mei");
      valid_pinyins.add("men");
      valid_pinyins.add("meng");
      valid_pinyins.add("mi");
      valid_pinyins.add("mian");
      valid_pinyins.add("miao");
      valid_pinyins.add("mie");
      valid_pinyins.add("min");
      valid_pinyins.add("ming");
      valid_pinyins.add("miu");
      valid_pinyins.add("mo");
      valid_pinyins.add("mou");
      valid_pinyins.add("mu");
      valid_pinyins.add("na");
      valid_pinyins.add("nai");
      valid_pinyins.add("nan");
      valid_pinyins.add("nang");
      valid_pinyins.add("nao");
      valid_pinyins.add("ne");
      valid_pinyins.add("nei");
      valid_pinyins.add("nen");
      valid_pinyins.add("neng");
      valid_pinyins.add("ni");
      valid_pinyins.add("nian");
      valid_pinyins.add("niang");
      valid_pinyins.add("niao");
      valid_pinyins.add("nie");
      valid_pinyins.add("nin");
      valid_pinyins.add("ning");
      valid_pinyins.add("niu");
      valid_pinyins.add("nong");
      valid_pinyins.add("nou");
      valid_pinyins.add("nu");
      valid_pinyins.add("nuan");
      // valid_pinyins.add("nue"); // not standard, ignore
      valid_pinyins.add("nuo");
      valid_pinyins.add("nv");
      valid_pinyins.add("nü");
      valid_pinyins.add("nve");
      valid_pinyins.add("nüe");
      valid_pinyins.add("pa");
      valid_pinyins.add("pai");
      valid_pinyins.add("pan");
      valid_pinyins.add("pang");
      valid_pinyins.add("pao");
      valid_pinyins.add("pei");
      valid_pinyins.add("pen");
      valid_pinyins.add("peng");
      valid_pinyins.add("pi");
      valid_pinyins.add("pian");
      valid_pinyins.add("piao");
      valid_pinyins.add("pie");
      valid_pinyins.add("pin");
      valid_pinyins.add("ping");
      valid_pinyins.add("po");
      valid_pinyins.add("pou");
      valid_pinyins.add("pu");
      valid_pinyins.add("qi");
      valid_pinyins.add("qia");
      valid_pinyins.add("qian");
      valid_pinyins.add("qiang");
      valid_pinyins.add("qiao");
      valid_pinyins.add("qie");
      valid_pinyins.add("qin");
      valid_pinyins.add("qing");
      valid_pinyins.add("qiong");
      valid_pinyins.add("qiu");
      valid_pinyins.add("qu");
      valid_pinyins.add("quan");
      valid_pinyins.add("que");
      valid_pinyins.add("qun");
      valid_pinyins.add("ran");
      valid_pinyins.add("rang");
      valid_pinyins.add("rao");
      valid_pinyins.add("re");
      valid_pinyins.add("ren");
      valid_pinyins.add("reng");
      valid_pinyins.add("ri");
      valid_pinyins.add("rong");
      valid_pinyins.add("rou");
      valid_pinyins.add("ru");
      valid_pinyins.add("ruan");
      valid_pinyins.add("rui");
      valid_pinyins.add("run");
      valid_pinyins.add("ruo");
      valid_pinyins.add("sa");
      valid_pinyins.add("sai");
      valid_pinyins.add("san");
      valid_pinyins.add("sang");
      valid_pinyins.add("sao");
      valid_pinyins.add("se");
      valid_pinyins.add("sen");
      valid_pinyins.add("seng");
      valid_pinyins.add("sha");
      valid_pinyins.add("shai");
      valid_pinyins.add("shan");
      valid_pinyins.add("shang");
      valid_pinyins.add("shao");
      valid_pinyins.add("she");
      valid_pinyins.add("shei");
      valid_pinyins.add("shen");
      valid_pinyins.add("sheng");
      valid_pinyins.add("shi");
      valid_pinyins.add("shou");
      valid_pinyins.add("shu");
      valid_pinyins.add("shua");
      valid_pinyins.add("shuai");
      valid_pinyins.add("shuan");
      valid_pinyins.add("shuang");
      valid_pinyins.add("shui");
      valid_pinyins.add("shun");
      valid_pinyins.add("shuo");
      valid_pinyins.add("si");
      valid_pinyins.add("song");
      valid_pinyins.add("sou");
      valid_pinyins.add("su");
      valid_pinyins.add("suan");
      valid_pinyins.add("sui");
      valid_pinyins.add("sun");
      valid_pinyins.add("suo");
      valid_pinyins.add("ta");
      valid_pinyins.add("tai");
      valid_pinyins.add("tan");
      valid_pinyins.add("tang");
      valid_pinyins.add("tao");
      valid_pinyins.add("te");
      valid_pinyins.add("teng");
      valid_pinyins.add("ti");
      valid_pinyins.add("tian");
      valid_pinyins.add("tiao");
      valid_pinyins.add("tie");
      valid_pinyins.add("ting");
      valid_pinyins.add("tong");
      valid_pinyins.add("tou");
      valid_pinyins.add("tu");
      valid_pinyins.add("tuan");
      valid_pinyins.add("tui");
      valid_pinyins.add("tun");
      valid_pinyins.add("tuo");
      valid_pinyins.add("wa");
      valid_pinyins.add("wai");
      valid_pinyins.add("wan");
      valid_pinyins.add("wang");
      valid_pinyins.add("wei");
      valid_pinyins.add("wen");
      valid_pinyins.add("weng");
      valid_pinyins.add("wo");
      valid_pinyins.add("wu");
      valid_pinyins.add("xi");
      valid_pinyins.add("xia");
      valid_pinyins.add("xian");
      valid_pinyins.add("xiang");
      valid_pinyins.add("xiao");
      valid_pinyins.add("xie");
      valid_pinyins.add("xin");
      valid_pinyins.add("xing");
      valid_pinyins.add("xiong");
      valid_pinyins.add("xiu");
      valid_pinyins.add("xu");
      valid_pinyins.add("xuan");
      valid_pinyins.add("xue");
      valid_pinyins.add("xun");
      valid_pinyins.add("ya");
      valid_pinyins.add("yai");
      valid_pinyins.add("yan");
      valid_pinyins.add("yang");
      valid_pinyins.add("yao");
      valid_pinyins.add("ye");
      valid_pinyins.add("yi");
      valid_pinyins.add("yin");
      valid_pinyins.add("ying");
      valid_pinyins.add("yo");
      valid_pinyins.add("yong");
      valid_pinyins.add("you");
      valid_pinyins.add("yu");
      valid_pinyins.add("yuan");
      valid_pinyins.add("yue");
      valid_pinyins.add("yun");
      valid_pinyins.add("za");
      valid_pinyins.add("zai");
      valid_pinyins.add("zan");
      valid_pinyins.add("zang");
      valid_pinyins.add("zao");
      valid_pinyins.add("ze");
      valid_pinyins.add("zei");
      valid_pinyins.add("zen");
      valid_pinyins.add("zeng");
      valid_pinyins.add("zha");
      valid_pinyins.add("zhai");
      valid_pinyins.add("zhan");
      valid_pinyins.add("zhang");
      valid_pinyins.add("zhao");
      valid_pinyins.add("zhe");
      valid_pinyins.add("zhen");
      valid_pinyins.add("zheng");
      valid_pinyins.add("zhi");
      valid_pinyins.add("zhong");
      valid_pinyins.add("zhou");
      valid_pinyins.add("zhu");
      valid_pinyins.add("zhua");
      valid_pinyins.add("zhuai");
      valid_pinyins.add("zhuan");
      valid_pinyins.add("zhuang");
      valid_pinyins.add("zhui");
      valid_pinyins.add("zhun");
      valid_pinyins.add("zhuo");
      valid_pinyins.add("zi");
      valid_pinyins.add("zong");
      valid_pinyins.add("zou");
      valid_pinyins.add("zu");
      valid_pinyins.add("zuan");
      valid_pinyins.add("zui");
      valid_pinyins.add("zun");
      valid_pinyins.add("zuo");

      valid_pinyins.add("a");
      valid_pinyins.add("e");
      valid_pinyins.add("ei");
      valid_pinyins.add("ai");
      valid_pinyins.add("ei");
      valid_pinyins.add("ao");
      valid_pinyins.add("o");
      valid_pinyins.add("ou");
      valid_pinyins.add("an");
      valid_pinyins.add("en");
      valid_pinyins.add("ang");
      // valid_pinyins.add("eng");
      valid_pinyins.add("er");

      // calculate valid_partial_pinyins
      foreach (string s in valid_pinyins) {
        for (int i = 1; i <= s.length; i++) {
          valid_partial_pinyins.add(s[0:i]);
        }
      }

      // hardcoded consonant <-> id, vowel <-> id tables
      consonant_ids = new HashMap<string, int>();
      vowel_ids = new HashMap<string, int>();

      consonant_ids["b"] = 1;
      consonant_ids["c"] = 2;
      consonant_ids["ch"] = 3;
      consonant_ids["d"] = 4;
      consonant_ids["f"] = 5;
      consonant_ids["g"] = 6;
      consonant_ids["h"] = 7;
      consonant_ids["j"] = 8;
      consonant_ids["k"] = 9;
      consonant_ids["l"] = 10;
      consonant_ids["m"] = 11;
      consonant_ids["n"] = 12;
      consonant_ids["p"] = 13;
      consonant_ids["q"] = 14;
      consonant_ids["r"] = 15;
      consonant_ids["s"] = 16;
      consonant_ids["sh"] = 17;
      consonant_ids["t"] = 18;
      consonant_ids["w"] = 19;
      consonant_ids["x"] = 20;
      consonant_ids["y"] = 21;
      consonant_ids["z"] = 22;
      consonant_ids["zh"] = 23;

      vowel_ids["a"] = 24;
      vowel_ids["ai"] = 25;
      vowel_ids["an"] = 26;
      vowel_ids["ang"] = 27;
      vowel_ids["ao"] = 28;
      vowel_ids["e"] = 29;
      vowel_ids["ei"] = 30;
      vowel_ids["en"] = 31;
      vowel_ids["eng"] = 32;
      vowel_ids["er"] = 33;
      vowel_ids["i"] = 34;
      vowel_ids["ia"] = 35;
      vowel_ids["ian"] = 36;
      vowel_ids["iang"] = 37;
      vowel_ids["iao"] = 38;
      vowel_ids["ie"] = 39;
      vowel_ids["in"] = 40;
      vowel_ids["ing"] = 41;
      vowel_ids["iong"] = 42;
      vowel_ids["iu"] = 43; // iou
      vowel_ids["o"] = 44;
      vowel_ids["ong"] = 45;
      vowel_ids["ou"] = 46;
      vowel_ids["u"] = 47;
      vowel_ids["ua"] = 48;
      vowel_ids["uai"] = 49;
      vowel_ids["uan"] = 50; // uan, üan (j,q,x,y,w), always see 'uan'
      vowel_ids["uang"] = 51;
      vowel_ids["ue"] = 52; 
      vowel_ids["üe"] = 52; // üe: lüe, nüe
      vowel_ids["ve"] = 52;
      vowel_ids["ui"] = 53; // uei
      vowel_ids["un"] = 54; // un: ün, uen, always see 'un'
      vowel_ids["uo"] = 55;
      vowel_ids["v"] = 56;
      vowel_ids["ü"] = 56; // lü, nü

      consonant_reverse_ids = new HashMap<int, string>();
      vowel_reverse_ids = new HashMap<int, string>();

      foreach (var entry in consonant_ids)
        consonant_reverse_ids[entry.value] = entry.key;

      foreach (var entry in vowel_ids)
        vowel_reverse_ids[entry.value] = entry.key;

      // for some special ones: ü
      vowel_reverse_ids[56] = "ü";
      vowel_reverse_ids[52] = "ue";

      // for zero consonant
      consonant_reverse_ids[0] = "";

      // for partial pinyin
      vowel_reverse_ids[-1] = "";

      // adjust cutting list
      cutting_adjusts = new HashMap<string, string>();
      cutting_adjusts["angang"] = "an gang";
      cutting_adjusts["ange"] = "an ge";
      cutting_adjusts["bana"] = "ba na";

      cutting_adjusts["bange"] = "ban ge";
      cutting_adjusts["bengai"] = "ben gai";
      cutting_adjusts["binan"] = "bi nan";
      cutting_adjusts["chana"] = "cha na";

      cutting_adjusts["chenei"] = "che nei";
      cutting_adjusts["chengang"] = "chen gang";
      cutting_adjusts["chuangan"] = "chuan gan";
      cutting_adjusts["chuangei"] = "chuan gei";
      cutting_adjusts["chuna"] = "chu na";
      cutting_adjusts["chunan"] = "chu nan";
      cutting_adjusts["danai"] = "da nai";

      cutting_adjusts["danao"] = "da nao";
      cutting_adjusts["daneng"] = "da neng";
      cutting_adjusts["dangai"] = "dan gai";
      cutting_adjusts["dangang"] = "dan gang";
      cutting_adjusts["dangao"] = "dan gao";
      cutting_adjusts["dange"] = "dan ge";
      cutting_adjusts["dunang"] = "du nang";
      cutting_adjusts["eran"] = "e ran";

      cutting_adjusts["eren"] = "e ren";
      cutting_adjusts["fangao"] = "fan gao";

      cutting_adjusts["fenge"] = "fen ge";
      cutting_adjusts["fengei"] = "fen gei";
      cutting_adjusts["ganga"] = "gan ga";

      cutting_adjusts["gangan"] = "gan gan";
      cutting_adjusts["guao"] = "gu ao";
      cutting_adjusts["guangai"] = "guan gai";
      cutting_adjusts["hangai"] = "han gai";

      cutting_adjusts["henan"] = "he nan";
      cutting_adjusts["henei"] = "he nei";
      cutting_adjusts["heneng"] = "he neng";
      cutting_adjusts["hengao"] = "hen gao";
      cutting_adjusts["huana"] = "hua na";
      cutting_adjusts["huanan"] = "hua nan";
      cutting_adjusts["huaneng"] = "hua neng";
      cutting_adjusts["huange"] = "huan ge";
      cutting_adjusts["huangei"] = "huan gei";
      cutting_adjusts["hunao"] = "hu nao";
      cutting_adjusts["jiana"] = "jia na";

      cutting_adjusts["jianeng"] = "jia neng";
      cutting_adjusts["jiange"] = "jian ge";
      cutting_adjusts["jiangou"] = "jian gou";
      cutting_adjusts["jinan"] = "ji nan";
      cutting_adjusts["jineng"] = "ji neng";
      cutting_adjusts["jingang"] = "jin gang";
      cutting_adjusts["jingen"] = "jin gen";
      cutting_adjusts["kange"] = "kan ge";

      cutting_adjusts["kena"] = "ke na";
      cutting_adjusts["kenan"] = "ke nan";
      cutting_adjusts["keneng"] = "ke neng";
      cutting_adjusts["kunan"] = "ku nan";
      cutting_adjusts["kunao"] = "ku nao";
      cutting_adjusts["langan"] = "lan gan";

      cutting_adjusts["liangang"] = "lian gang";
      cutting_adjusts["liange"] = "lian ge";
      cutting_adjusts["lina"] = "li na";
      cutting_adjusts["lingang"] = "lin gang";
      cutting_adjusts["lunei"] = "lu nei";
      cutting_adjusts["luneng"] = "lu neng";
      cutting_adjusts["manao"] = "ma nao";

      cutting_adjusts["nana"] = "na na";

      cutting_adjusts["nane"] = "na ne";
      cutting_adjusts["naneng"] = "na neng";
      cutting_adjusts["nangao"] = "nan gao";
      cutting_adjusts["niangao"] = "nian gao";
      cutting_adjusts["ninan"] = "ni nan";
      cutting_adjusts["nineng"] = "ni neng";
      cutting_adjusts["pangang"] = "pan gang";

      cutting_adjusts["pinge"] = "pin ge";
      cutting_adjusts["qinang"] = "qi nang";

      cutting_adjusts["qinei"] = "qi nei";
      cutting_adjusts["qineng"] = "qi neng";
      cutting_adjusts["quna"] = "qu na";
      cutting_adjusts["qunei"] = "qu nei";
      cutting_adjusts["renao"] = "re nao";

      cutting_adjusts["reneng"] = "re neng";
      cutting_adjusts["rengan"] = "ren gan";
      cutting_adjusts["renge"] = "ren ge";
      cutting_adjusts["rengou"] = "ren gou";
      cutting_adjusts["runei"] = "ru nei";
      cutting_adjusts["runeng"] = "ru neng";
      cutting_adjusts["sange"] = "san ge";

      cutting_adjusts["sangen"] = "san gen";
      cutting_adjusts["sangeng"] = "san geng";
      cutting_adjusts["shangao"] = "shan gao";
      cutting_adjusts["shange"] = "shan ge";
      cutting_adjusts["shangou"] = "shan gou";
      cutting_adjusts["shengan"] = "shen gan";
      cutting_adjusts["shengang"] = "shen gang";
      cutting_adjusts["shengao"] = "shen gao";
      cutting_adjusts["shengou"] = "shen gou";
      cutting_adjusts["sunan"] = "su nan";
      cutting_adjusts["tange"] = "tan ge";

      cutting_adjusts["wange"] = "wan ge";

      cutting_adjusts["wengao"] = "wen gao";
      cutting_adjusts["wenge"] = "wen ge";
      cutting_adjusts["xiangei"] = "xian gei";

      cutting_adjusts["xina"] = "xi na";
      cutting_adjusts["xinao"] = "xi nao";
      cutting_adjusts["xinen"] = "xi nen";
      cutting_adjusts["xingan"] = "xin gan";
      cutting_adjusts["xingang"] = "xin gang";
      cutting_adjusts["xingao"] = "xin gao";
      cutting_adjusts["xinge"] = "xin ge";
      cutting_adjusts["yangai"] = "yan gai";

      cutting_adjusts["yange"] = "yan ge";
      cutting_adjusts["yinei"] = "yi nei";
      cutting_adjusts["yineng"] = "yi neng";
      cutting_adjusts["yunan"] = "yu nan";
      cutting_adjusts["zange"] = "zan ge";

      cutting_adjusts["zenan"] = "ze nan";
      cutting_adjusts["zeneng"] = "ze neng";
      cutting_adjusts["zhangang"] = "zhan gang";
      cutting_adjusts["zhange"] = "zhan ge";
      cutting_adjusts["zhene"] = "zhe ne";
      cutting_adjusts["zhenge"] = "zhen ge";
      cutting_adjusts["zhengou"] = "zhen gou";
      cutting_adjusts["zhuangao"] = "zhuan gao";
      cutting_adjusts["zhuangei"] = "zhuan gei";
      cutting_adjusts["zunao"] = "zu nao";

      // init double pinyin
      DoublePinyin.init();
    }
  }
}

/* vim:set et sts=2 tabstop=2 shiftwidth=2: */
