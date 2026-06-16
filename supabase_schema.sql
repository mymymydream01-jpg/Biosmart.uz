-- =============================================
-- BioSmart — Supabase Database Schema
-- =============================================

-- 1. Profiles (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  email TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  grade TEXT DEFAULT '7-sinf',
  is_pro BOOLEAN NOT NULL DEFAULT false,
  pro_plan TEXT CHECK (pro_plan IN ('monthly', 'annual')),
  pro_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Grades
CREATE TABLE IF NOT EXISTS grades (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,       -- '5-sinf', '6-sinf', ...
  display_order INT NOT NULL DEFAULT 0,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Subjects
CREATE TABLE IF NOT EXISTS subjects (
  id SERIAL PRIMARY KEY,
  grade_id INT NOT NULL REFERENCES grades(id) ON DELETE CASCADE,
  name TEXT NOT NULL,              -- 'Biologiya', 'Botanika', 'Zoologiya'
  description TEXT,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Topics
CREATE TABLE IF NOT EXISTS topics (
  id SERIAL PRIMARY KEY,
  subject_id INT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT,                    -- Mavzu matni (HTML yoki Markdown)
  reading_time INT DEFAULT 25,    -- daqiqalarda
  difficulty TEXT DEFAULT 'Easy' CHECK (difficulty IN ('Easy', 'Medium', 'Hard')),
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Questions
CREATE TABLE IF NOT EXISTS questions (
  id SERIAL PRIMARY KEY,
  topic_id INT NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  correct_answer TEXT NOT NULL,    -- 'A', 'B', 'C', 'D'
  explanation TEXT,
  difficulty TEXT DEFAULT 'Easy' CHECK (difficulty IN ('Easy', 'Medium', 'Hard')),
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Question Options
CREATE TABLE IF NOT EXISTS question_options (
  id SERIAL PRIMARY KEY,
  question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  option_label TEXT NOT NULL,      -- 'A', 'B', 'C', 'D'
  option_text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. Test Attempts
CREATE TABLE IF NOT EXISTS test_attempts (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  topic_id INT NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  score INT NOT NULL DEFAULT 0,
  total_questions INT NOT NULL DEFAULT 0,
  time_spent INT DEFAULT 0,       -- sekundlarda
  completed_at TIMESTAMPTZ DEFAULT now()
);

-- 8. User Progress (kitob o'qish progressi)
CREATE TABLE IF NOT EXISTS user_progress (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  topic_id INT NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  progress INT DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  last_accessed TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, topic_id)
);

-- 9. Certificates
CREATE TABLE IF NOT EXISTS certificates (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  topic_id INT NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  score INT NOT NULL,
  earned_at TIMESTAMPTZ DEFAULT now()
);

-- 10. Did You Know facts
CREATE TABLE IF NOT EXISTS did_you_know (
  id SERIAL PRIMARY KEY,
  fact_text TEXT NOT NULL,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- Row Level Security Policies
-- =============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE question_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE did_you_know ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read/update own, admins can read all
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can view all profiles" ON profiles FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Allow insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Content tables: readable by all authenticated users
CREATE POLICY "Grades readable by all" ON grades FOR SELECT USING (true);
CREATE POLICY "Subjects readable by all" ON subjects FOR SELECT USING (true);
CREATE POLICY "Topics readable by all" ON topics FOR SELECT USING (true);
CREATE POLICY "Questions readable by all" ON questions FOR SELECT USING (true);
CREATE POLICY "Options readable by all" ON question_options FOR SELECT USING (true);
CREATE POLICY "Facts readable by all" ON did_you_know FOR SELECT USING (true);

-- Admin can manage content
CREATE POLICY "Admins manage grades" ON grades FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins manage subjects" ON subjects FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins manage topics" ON topics FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins manage questions" ON questions FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins manage options" ON question_options FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins manage facts" ON did_you_know FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- User data: own data only
CREATE POLICY "Users own test attempts" ON test_attempts FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users own progress" ON user_progress FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users own certificates" ON certificates FOR ALL USING (auth.uid() = user_id);

-- Admins can view all user data
CREATE POLICY "Admins view all attempts" ON test_attempts FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins view all progress" ON user_progress FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Admins view all certificates" ON certificates FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- =============================================
-- Auto-create profile on signup (trigger)
-- =============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', ''), NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================
-- Seed Data
-- =============================================

-- Grades
INSERT INTO grades (name, display_order) VALUES
  ('5-sinf', 1), ('6-sinf', 2), ('7-sinf', 3), ('8-sinf', 4),
  ('9-sinf', 5), ('10-sinf', 6), ('11-sinf', 7)
ON CONFLICT (name) DO NOTHING;

-- Subjects for each grade
INSERT INTO subjects (grade_id, name, description) VALUES
  (1, 'Biologiya', 'Tirik organizmlar haqida umumiy tushunchalar'),
  (2, 'Botanika', 'O''simliklar dunyosi'),
  (3, 'Zoologiya', 'Hayvonot dunyosi'),
  (4, 'Odam va uning salomatligi', 'Inson anatomiyasi va fiziologiyasi'),
  (5, 'Biologiya', 'Umumiy biologiya asoslari'),
  (6, 'Biologiya', 'Genetika va evolyutsiya'),
  (7, 'Biologiya', 'Molekulyar biologiya');

-- Topics for 7-sinf Zoologiya (grade_id=3)
INSERT INTO topics (subject_id, title, reading_time, difficulty, display_order, content) VALUES
  (3, 'Hayvonot dunyosining xilma-xilligi', 25, 'Easy', 1, 
   'Hayvonot dunyosi juda xilma-xildir. Yer yuzida 1,5 milliondan ortiq hayvon turi mavjud. Ular bir hujayrali va ko''p hujayrali organizmlarga bo''linadi. Hayvonlar o''simliklardan farqli ravishda tayyor organik moddalar bilan oziqlanadi, ya''ni geterotrof organizmlarga kiradi.'),
  (3, 'Umurtqasiz hayvonlar', 20, 'Medium', 2,
   'Umurtqasiz hayvonlar — bu umurtqa pog''onasi bo''lmagan hayvonlar. Ularga quyidagilar kiradi: sodda hayvonlar, bo''shliqichlilar, chuvalchanglar, bo''g''imoyoqlilar, mollyuskalar va boshqalar.'),
  (3, 'Umurtqali hayvonlar', 30, 'Easy', 3,
   'Umurtqali hayvonlar ichki skeletga ega bo''lib, ular baliqlar, amfibiyalar, reptiliyalar, qushlar va sutemizuvchilarga bo''linadi. Ular hayvonot dunyosining eng murakkab vakillari hisoblanadi.'),
  (3, 'Sutemizuvchilar sinfi', 25, 'Hard', 4,
   'Sutemizuvchilar — eng rivojlangan hayvonlar sinfi. Ular bolalarini sut bilan boqadi, tanasi jun bilan qoplangan, issiq qonli hayvonlardir. Sutemizuvchilar 20 dan ortiq turkumga bo''linadi.'),
  (3, 'Qushlar sinfi', 30, 'Medium', 5,
   'Qushlar — issiq qonli, tuxum qo''yuvchi umurtqali hayvonlar. Ularning tanasi patlar bilan qoplangan bo''lib, oldingi oyoqlari qanotlarga aylangan. Dunyoda 10 000 dan ortiq qush turi mavjud.');

-- Questions for "Hayvonot dunyosining xilma-xilligi"
INSERT INTO questions (topic_id, question_text, correct_answer, difficulty, explanation) VALUES
  (1, 'Yer yuzida taxminan qancha hayvon turi mavjud?', 'A', 'Easy', 'Yer yuzida 1,5 milliondan ortiq hayvon turi aniqlangan.'),
  (2, 'Fotosintez jarayonida qaysi gaz ajralib chiqadi?', 'A', 'Easy', 'Fotosintez jarayonida kislorod gazi ajralib chiqadi.'),
  (1, 'Hayvonlar qanday oziqlanish usulga ega?', 'B', 'Medium', 'Hayvonlar geterotrof organizmlar bo''lib, tayyor organik moddalar bilan oziqlanadi.'),
  (1, 'Quyidagilardan qaysi biri bir hujayrali hayvonga misol bo''la oladi?', 'C', 'Easy', 'Amyoba bir hujayrali hayvonlarning eng mashhur vakilidir.'),
  (2, 'Qaysi hayvonlar umurtqasiz hayvonlarga kiradi?', 'D', 'Medium', 'Chuvalchanglar umurtqasiz hayvonlarga kiradi.'),
  (3, 'Umurtqali hayvonlarning eng murakkab vakillari qaysilar?', 'A', 'Hard', 'Sutemizuvchilar umurtqali hayvonlarning eng murakkab vakillari hisoblanadi.'),
  (4, 'Sutemizuvchilar qancha turkumga bo''linadi?', 'B', 'Medium', 'Sutemizuvchilar 20 dan ortiq turkumga bo''linadi.'),
  (5, 'Dunyoda qancha qush turi mavjud?', 'C', 'Easy', 'Dunyoda 10 000 dan ortiq qush turi mavjud.'),
  (1, 'Biologiya fani nimani o''rganadi?', 'A', 'Easy', 'Biologiya tirik organizmlarni o''rganuvchi fan.'),
  (3, 'Baliqlar qaysi guruhga kiradi?', 'B', 'Easy', 'Baliqlar umurtqali hayvonlar guruhiga kiradi.');

-- Question Options
INSERT INTO question_options (question_id, option_label, option_text) VALUES
  (1, 'A', '1,5 milliondan ortiq'), (1, 'B', '500 ming'), (1, 'C', '100 ming'), (1, 'D', '10 million'),
  (2, 'A', 'Kislorod'), (2, 'B', 'Azot'), (2, 'C', 'Karbonat angidrid'), (2, 'D', 'Geliy'),
  (3, 'A', 'Avtotrof'), (3, 'B', 'Geterotrof'), (3, 'C', 'Xemotrof'), (3, 'D', 'Fototrof'),
  (4, 'A', 'Bakteriya'), (4, 'B', 'Virus'), (4, 'C', 'Amyoba'), (4, 'D', 'Zamburug'''),
  (5, 'A', 'Baliqlar'), (5, 'B', 'Qushlar'), (5, 'C', 'Sutemizuvchilar'), (5, 'D', 'Chuvalchanglar'),
  (6, 'A', 'Sutemizuvchilar'), (6, 'B', 'Baliqlar'), (6, 'C', 'Amfibiyalar'), (6, 'D', 'Reptiliyalar'),
  (7, 'A', '10'), (7, 'B', '20 dan ortiq'), (7, 'C', '5'), (7, 'D', '50'),
  (8, 'A', '1 000'), (8, 'B', '5 000'), (8, 'C', '10 000 dan ortiq'), (8, 'D', '100 000'),
  (9, 'A', 'Tirik organizmlarni'), (9, 'B', 'Kimyoviy moddalarni'), (9, 'C', 'Yulduzlarni'), (9, 'D', 'Tog'' jinslarini'),
  (10, 'A', 'Umurtqasiz hayvonlar'), (10, 'B', 'Umurtqali hayvonlar'), (10, 'C', 'Sodda hayvonlar'), (10, 'D', 'Bo''g''imoyoqlilar');

-- Did You Know facts
INSERT INTO did_you_know (fact_text) VALUES
  ('Asal hech qachon buzilmaydi. Arxeologlar Misr piramidalaridan 3000 yillik asal topishgan va u hali ham iste''mol qilish mumkin edi!'),
  ('Oktopusning 3 ta yuragi bor. Ikkitasi qonni oyoqlarga, bittasi esa tanaga qon yuboradi.'),
  ('Inson tanasida taxminan 37,2 trillion hujayra mavjud.'),
  ('Baobab daraxti o''z tanasida 120 000 litrgacha suv saqlashi mumkin.'),
  ('Delfin uyquda ham bir ko''zi ochiq bo''ladi, chunki miyasining faqat yarmi uxlaydi.'),
  ('DNK molekulasining uzunligi 2 metrga yetadi, lekin u hujayraning yadrosiga joylashadi.'),
  ('Kamalak 12 ta rangni ko''ra oladi, inson esa atigi 3 ta (qizil, yashil, ko''k).'),
  ('Eng kichik sut emizuvchi — bumblebee ko''rshapalak, og''irligi atigi 2 gramm.');
