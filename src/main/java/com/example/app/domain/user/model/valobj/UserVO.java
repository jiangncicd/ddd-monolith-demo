package com.example.app.domain.user.model.valobj;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 值对象：用户信息。领域层对外暴露的是 VO，而非数据库 PO。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserVO {
    private String userId;
    private String userName;
    private int age;
    private String gender;
}
