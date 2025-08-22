/**
 * JavaScript桥接接口
 */
export interface JsBridge {
  /**
   * 注册JS模块
   * @param moduleName 模块名称
   * @param module JS模块实例
   */
  registerModule(moduleName: string, module: Object): void;

  /**
   * 注销JS模块
   * @param moduleName 模块名称
   */
  unregisterModule(moduleName: string): void;

  /**
   * 调用JS方法
   * @param moduleName 模块名称
   * @param methodName 方法名称
   * @param params 参数
   */
  callJsMethod(moduleName: string, methodName: string, params?: Object): void;

  /**
   * 获取所有注册的模块
   */
  getAllModules(): Map<string, Object>;
}