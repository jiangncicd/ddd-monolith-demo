package com.example.app.infrastructure.repository;

import com.example.app.domain.user.model.valobj.UserVO;
import com.example.app.domain.user.repository.IUserRepository;
import com.example.app.infrastructure.dao.UserDao;
import com.example.app.infrastructure.po.UserPO;
import org.springframework.stereotype.Repository;

import javax.annotation.Resource;

/**
 * 依赖倒置的落地点：infrastructure 实现 domain 定义的仓储接口。
 * PO -> VO 的转换锁在这一层，领域层拿到的永远是领域对象。
 */
@Repository
public class UserRepository implements IUserRepository {

    @Resource
    private UserDao userDao;

    @Override
    public UserVO queryUserById(String userId) {
        UserPO po = userDao.selectByUserId(userId);
        if (po == null) {
            return null;
        }
        return UserVO.builder()
                .userId(po.getUserId())
                .userName(po.getUserName())
                .age(po.getAge())
                .gender(po.getGender())
                .build();
    }
}
