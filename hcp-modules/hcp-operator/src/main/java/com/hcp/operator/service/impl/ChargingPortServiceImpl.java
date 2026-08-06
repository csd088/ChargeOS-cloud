package com.hcp.operator.service.impl;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

import cn.hutool.core.collection.CollUtil;
import cn.hutool.core.util.StrUtil;
import com.hcp.common.core.exception.ServiceException;
import com.hcp.common.core.web.domain.AjaxResult;
import com.hcp.operator.domain.BatchPortReq;
import com.hcp.operator.mapper.ChargingPileMapper;
import com.hcp.system.api.domain.ChargingPile;
import com.hcp.system.api.domain.ChargingPort;
import com.hcp.system.api.domain.vo.PilePortVO;
import com.hcp.system.api.domain.vo.PlotInfoReqVO;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.hcp.operator.mapper.ChargingPortMapper;
import com.hcp.operator.service.IChargingPortService;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.hcp.common.core.text.Convert;
import com.hcp.common.core.utils.ServletUtils;
import com.hcp.common.mybatisplus.constant.MybatisPageConstants;
/**
 * 充电桩端口Service业务层处理
 *
 * @author hcp
 * @date 2024-08-06
 */
@Service
public class ChargingPortServiceImpl implements IChargingPortService
{
    @Autowired
    private ChargingPortMapper chargingPortMapper;

    @Autowired
    private ChargingPileMapper chargingPileMapper;

    /**
     * 充电桩端口 状态  N是未使用 Y 在使用 F是故障
     */
    public static final String PORT_STATE_N = "N";
    /**
     *  N是未使用 Y 在使用 F是故障
     */
    public static final String PORT_STATE_Y = "Y";
    /**
     *  N是未使用 Y 在使用 F是故障
     */
    public static final String PORT_STATE_F = "F";
    /**
     * 指令 1 开 0 关
     */
    public static final Integer SWITCH_CLOSE = 0;
    public static final Integer SWITCH_OPEN = 1;

    /**
     * 查询充电桩端口
     *
     * @param portId 充电桩端口主键
     * @return 充电桩端口
     */
    @Override
    public ChargingPort selectChargingPortByPortId(Long portId)
    {
        return chargingPortMapper.selectByPrimaryKey(portId);
    }

    /**
     * 查询充电桩端口列表-分页
     *
     * @param chargingPort 充电桩端口
     * @return 充电桩端口
     */
    @Override
    public IPage<ChargingPort> selectChargingPortPage(ChargingPort chargingPort)
    {
        Page mpPage =new Page(Convert.toLong(ServletUtils.getParameterToInt(MybatisPageConstants.PAGE_NUM),1L)
                ,Convert.toLong(ServletUtils.getParameterToInt(MybatisPageConstants.PAGE_SIZE),10L));
        return chargingPortMapper.selectChargingPortList(mpPage,chargingPort);
    }
    /**
     * 查询充电桩端口列表
     *
     * @param chargingPort 充电桩端口
     * @return 充电桩端口
     */
    @Override
    public List<ChargingPort> selectChargingPortList(ChargingPort chargingPort)
    {
        return chargingPortMapper.selectChargingPortList(chargingPort);
    }

    /**
     * 新增充电桩端口
     *
     * @param chargingPort 充电桩端口
     * @return 结果
     */

    @Override
    public int insertChargingPort(ChargingPort chargingPort)
    {
        return chargingPortMapper.insert(chargingPort);
    }

    /**
     * 修改充电桩端口
     *
     * @param chargingPort 充电桩端口
     * @return 结果
     */
    @Override
    public int updateChargingPort(ChargingPort chargingPort)
    {
        return chargingPortMapper.updateById(chargingPort);
    }

    /**
     * 批量新增充电桩端口（按枪数自动生成 A枪/B枪/C枪...）
     *
     * @param req 批量新增请求
     * @return 结果
     */
    @Override
    public int batchInsertPorts(BatchPortReq req)
    {
        if (req == null || StrUtil.isBlank(req.getPileId())) {
            throw new ServiceException("充电桩编号不能为空");
        }
        Integer gunCount = req.getGunCount();
        if (gunCount == null || gunCount <= 0) {
            throw new ServiceException("枪口数量必须大于0");
        }
        if (gunCount > 64) {
            throw new ServiceException("枪口数量过大，单次最多64枪");
        }
        ChargingPile pile = chargingPileMapper.getById(req.getPileId());
        if (pile == null) {
            throw new ServiceException("充电桩不存在");
        }
        // 该桩已存在端口则不允许重复批量新增
        List<ChargingPort> existing = selectPortByPileId(req.getPileId());
        if (CollUtil.isNotEmpty(existing)) {
            throw new ServiceException("该桩已存在端口，不能重复批量新增");
        }
        Date now = new Date();
        List<ChargingPort> list = new ArrayList<>();
        for (int i = 1; i <= gunCount; i++) {
            ChargingPort port = new ChargingPort();
            port.setPileId(req.getPileId());
            port.setDeviceId(String.valueOf(i));
            port.setName(generateGunName(i));
            port.setState(PORT_STATE_N);
            port.setTenantId(pile.getTenantId());
            port.setCreateTime(now);
            list.add(port);
        }
        return chargingPortMapper.insertBatchPorts(list);
    }

    /**
     * 生成枪口名称：1-26为A枪~Z枪，超出后使用 N号枪
     */
    private String generateGunName(int index)
    {
        if (index <= 26) {
            char c = (char) ('A' + index - 1);
            return c + "枪";
        }
        return index + "号枪";
    }

    /**
     * 批量删除充电桩端口
     *
     * @param portIds 需要删除的充电桩端口主键
     * @return 结果
     */
    @Override
    public int deleteChargingPortByPortIds(Long[] portIds)
    {
        return chargingPortMapper.deleteChargingPortByPortIds(portIds);
    }

    /**
     * 删除充电桩端口信息
     *
     * @param portId 充电桩端口主键
     * @return 结果
     */
    @Override
    public int deleteChargingPortByPortId(Long portId)
    {
        return chargingPortMapper.deleteById(portId);
    }


    @Override
    public AjaxResult switchPort(Integer id, Integer type) {

        if (!SWITCH_CLOSE.equals(type) && !SWITCH_OPEN.equals(type)){
            return AjaxResult.error(-2, "端口操作状态值不对！");
        }
        ChargingPort chargingPort = chargingPortMapper.selectById(id);
        if (null == chargingPort) {
            return AjaxResult.error(-3, "端口不存在！");
        }
        // 开启，状态修改为未占用，关闭 修改为故障
        if (SWITCH_CLOSE.equals(type)) {
            chargingPort.setState(PORT_STATE_F);
        }
        if (SWITCH_OPEN.equals(type)) {
            chargingPort.setState(PORT_STATE_N);
        }
        chargingPortMapper.updateById(chargingPort);
        return AjaxResult.success();
    }

    @Override
    public void updateGunStatus(String pileId, String port, String gunInsert) {
        ChargingPort chargingPort = chargingPortMapper.selectPort(pileId,port);
        assert chargingPort !=null;
        chargingPort.setGunInsert(gunInsert);
        chargingPortMapper.updateByPrimaryKey(chargingPort);
    }

    @Override
    public List<PilePortVO> queryPortInfoVo(PlotInfoReqVO plotInfoReqVO) {
        return chargingPortMapper.queryPortInfoVo(plotInfoReqVO);
    }

    @Override
    public List<ChargingPort> selectPortByPileId(String pileId) {
        ChargingPort port = new ChargingPort();
        port.setPileId(pileId);
        List<ChargingPort> list = chargingPortMapper.selectChargingPortList(port);
        return list;
    }
}
