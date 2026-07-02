package com.example.app.domain.user.repository;

import com.example.app.domain.user.model.valobj.UserVO;

/**
 * 仓储接口定义在领域层，实现放在 infrastructure（依赖倒置 DIP）。
 * 领域层不知道数据来自 MySQL / H2 / 缓存。
 */
public interface IUserRepository {
    UserVO queryUserById(String userId);
}
