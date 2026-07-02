package com.example.app.domain.user.service;

import com.example.app.domain.user.model.valobj.UserVO;
import com.example.app.domain.user.repository.IUserRepository;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;

/**
 * 用户领域服务：只依赖本领域的仓储接口。
 */
@Service
public class UserService {

    @Resource
    private IUserRepository userRepository;

    public UserVO queryUser(String userId) {
        return userRepository.queryUserById(userId);
    }
}
