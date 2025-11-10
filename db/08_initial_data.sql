-- ============================================
-- INITIAL DATA
-- ============================================

-- Insert common countries
INSERT INTO countries (country_code, country_name, country_currency_code, country_timezone) VALUES
    ('IL', 'Israel', 'ILS', 'Asia/Jerusalem'),
    ('US', 'United States', 'USD', 'America/New_York'),
    ('GB', 'United Kingdom', 'GBP', 'Europe/London'),
    ('DE', 'Germany', 'EUR', 'Europe/Berlin'),
    ('FR', 'France', 'EUR', 'Europe/Paris'),
    ('IT', 'Italy', 'EUR', 'Europe/Rome'),
    ('ES', 'Spain', 'EUR', 'Europe/Madrid'),
    ('NL', 'Netherlands', 'EUR', 'Europe/Amsterdam'),
    ('BE', 'Belgium', 'EUR', 'Europe/Brussels'),
    ('CH', 'Switzerland', 'CHF', 'Europe/Zurich'),
    ('AU', 'Australia', 'AUD', 'Australia/Sydney'),
    ('CA', 'Canada', 'CAD', 'America/Toronto'),
    ('JP', 'Japan', 'JPY', 'Asia/Tokyo'),
    ('CN', 'China', 'CNY', 'Asia/Shanghai'),
    ('IN', 'India', 'INR', 'Asia/Kolkata')
ON CONFLICT (country_code) DO NOTHING;

