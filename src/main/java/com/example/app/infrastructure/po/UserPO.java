package com.example.app.infrastructure.po;

import lombok.Data;

/**
 * 持久化对象（Persistent Object）。PO 只在 infrastructure 层出现，不外泄到领域层。
 */
@Data
public class UserPO {
    private Long id;
    private String userId;
    private String userName;
    private int age;
    private String gender;
}
