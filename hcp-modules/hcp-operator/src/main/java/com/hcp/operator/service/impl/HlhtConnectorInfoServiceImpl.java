package com.hcp.operator.service.impl;

import java.util.ArrayList;
import java.util.List;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import cn.hutool.core.util.StrUtil;
import com.hcp.common.core.exception.ServiceException;
import com.hcp.operator.mapper.HlhtEquipmentInfoMapper;
import com.hcp.operator.domain.HlhtEquipmentInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.hcp.operator.mapper.HlhtConnectorInfoMapper;
import com.hcp.operator.domain.BatchConnectorReq;
import com.hcp.operator.domain.HlhtConnectorInfo;
import com.hcp.operator.service.IHlhtConnectorInfoService;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.hcp.common.core.text.Convert;
import com.hcp.common.core.utils.ServletUtils;
import com.hcp.common.mybatisplus.constant.MybatisPageConstants;
/**
 * 接口信息Service业务层处理
 *
 * @author hcp
 * @date 2024-08-11
 */
@Service
public class HlhtConnectorInfoServiceImpl implements IHlhtConnectorInfoService
{
    @Autowired
    private HlhtConnectorInfoMapper hlhtConnectorInfoMapper;

    @Autowired
    private HlhtEquipmentInfoMapper hlhtEquipmentInfoMapper;

    /**
     * 查询接口信息
     *
     * @param connectorId 接口信息主键
     * @return 接口信息
     */
    @Override
    public HlhtConnectorInfo selectHlhtConnectorInfoByConnectorId(String connectorId)
    {
        return hlhtConnectorInfoMapper.selectById(connectorId);
    }

    /**
     * 查询接口信息列表-分页
     *
     * @param hlhtConnectorInfo 接口信息
     * @return 接口信息
     */
    @Override
    public IPage<HlhtConnectorInfo> selectHlhtConnectorInfoPage(HlhtConnectorInfo hlhtConnectorInfo)
    {
        Page mpPage =new Page(Convert.toLong(ServletUtils.getParameterToInt(MybatisPageConstants.PAGE_NUM),1L)
                ,Convert.toLong(ServletUtils.getParameterToInt(MybatisPageConstants.PAGE_SIZE),10L));
        return hlhtConnectorInfoMapper.selectHlhtConnectorInfoList(mpPage,hlhtConnectorInfo);
    }
    /**
     * 查询接口信息列表
     *
     * @param hlhtConnectorInfo 接口信息
     * @return 接口信息
     */
    @Override
    public List<HlhtConnectorInfo> selectHlhtConnectorInfoList(HlhtConnectorInfo hlhtConnectorInfo)
    {
        return hlhtConnectorInfoMapper.selectHlhtConnectorInfoList(hlhtConnectorInfo);
    }

    /**
     * 新增接口信息
     *
     * @param hlhtConnectorInfo 接口信息
     * @return 结果
     */

    @Override
    public int insertHlhtConnectorInfo(HlhtConnectorInfo hlhtConnectorInfo)
    {
        return hlhtConnectorInfoMapper.insert(hlhtConnectorInfo);
    }

    /**
     * 修改接口信息
     *
     * @param hlhtConnectorInfo 接口信息
     * @return 结果
     */
    @Override
    public int updateHlhtConnectorInfo(HlhtConnectorInfo hlhtConnectorInfo)
    {
        return hlhtConnectorInfoMapper.updateById(hlhtConnectorInfo);
    }

    /**
     * 批量新增充电接口（按枪数自动生成 connectorId=equipmentId+序号）
     *
     * @param req 批量新增请求
     * @return 结果
     */
    @Override
    public int batchInsertConnectors(BatchConnectorReq req)
    {
        if (req == null || StrUtil.isBlank(req.getEquipmentId())) {
            throw new ServiceException("设备编号不能为空");
        }
        Integer gunCount = req.getGunCount();
        if (gunCount == null || gunCount <= 0) {
            throw new ServiceException("枪口数量必须大于0");
        }
        if (gunCount > 64) {
            throw new ServiceException("枪口数量过大，单次最多64枪");
        }
        HlhtEquipmentInfo equipment = hlhtEquipmentInfoMapper.selectById(req.getEquipmentId());
        if (equipment == null) {
            throw new ServiceException("充电设备不存在");
        }
        // 该设备已存在接口则不允许重复批量新增
        Long existingCount = hlhtConnectorInfoMapper.selectCount(new LambdaQueryWrapper<HlhtConnectorInfo>()
                .eq(HlhtConnectorInfo::getEquipmentId, req.getEquipmentId()));
        if (existingCount != null && existingCount > 0) {
            throw new ServiceException("该设备已存在接口，不能重复批量新增");
        }
        List<HlhtConnectorInfo> list = new ArrayList<>();
        for (int i = 1; i <= gunCount; i++) {
            HlhtConnectorInfo connector = new HlhtConnectorInfo();
            connector.setConnectorId(req.getEquipmentId() + "_" + i);
            connector.setConnectorName(i + "号充电接口");
            connector.setEquipmentId(req.getEquipmentId());
            connector.setTenantId(equipment.getTenantId());
            list.add(connector);
        }
        return hlhtConnectorInfoMapper.insertBatchConnectors(list);
    }

    /**
     * 批量删除接口信息
     *
     * @param connectorIds 需要删除的接口信息主键
     * @return 结果
     */
    @Override
    public int deleteHlhtConnectorInfoByConnectorIds(String[] connectorIds)
    {
        return hlhtConnectorInfoMapper.deleteHlhtConnectorInfoByConnectorIds(connectorIds);
    }

    /**
     * 删除接口信息信息
     *
     * @param connectorId 接口信息主键
     * @return 结果
     */
    @Override
    public int deleteHlhtConnectorInfoByConnectorId(String connectorId)
    {
        return hlhtConnectorInfoMapper.deleteById(connectorId);
    }
}
