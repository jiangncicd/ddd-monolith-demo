-- Alice 25 岁：满足下单准入规则
INSERT INTO user_info (user_id, user_name, age, gender) VALUES ('U0001', 'Alice', 25, 'FEMALE');
-- Bob 16 岁：会被规则领域拒绝
INSERT INTO user_info (user_id, user_name, age, gender) VALUES ('U0002', 'Bob', 16, 'MALE');
