package com.example.app.infrastructure.dao;

import com.example.app.infrastructure.po.UserPO;
import org.springframework.jdbc.core.BeanPropertyRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import javax.annotation.Resource;
import java.util.List;

/**
 * DAO：贴着数据库的读写（这里用 JdbcTemplate；换 MyBatis / JPA 同理）。
 */
@Repository
public class UserDao {

    @Resource
    private JdbcTemplate jdbcTemplate;

    public UserPO selectByUserId(String userId) {
        List<UserPO> list = jdbcTemplate.query(
                "SELECT id, user_id, user_name, age, gender FROM user_info WHERE user_id = ?",
                new BeanPropertyRowMapper<>(UserPO.class),
                userId);
        return list.isEmpty() ? null : list.get(0);
    }
}
