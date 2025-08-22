/**
 * 生命周期接口
 */
export interface LifeCycle {
  /**
   * 初始化
   */
  onCreate(): void;

  /**
   * 开始
   */
  onStart(): void;

  /**
   * 恢复
   */
  onResume(): void;

  /**
   * 暂停
   */
  onPause(): void;

  /**
   * 停止
   */
  onStop(): void;

  /**
   * 销毁
   */
  onDestroy(): void;
}