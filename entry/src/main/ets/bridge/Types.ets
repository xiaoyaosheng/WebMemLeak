/**
 * 类型定义文件
 */

/**
 * JavaScript桥接对象接口
 */
export interface JsBridgeObject {
  callNative(method: string, params: string): void;
}

/**
 * JavaScript桥接对象具体实现类
 */
export class JsBridgeModule implements JsBridgeObject {
  private callNativeImpl: (method: string, params: string) => void;

  constructor(callNativeImpl: (method: string, params: string) => void) {
    this.callNativeImpl = callNativeImpl;
  }

  callNative(method: string, params: string): void {
    this.callNativeImpl(method, params);
  }
}

/**
 * 内存信息接口
 */
export interface MemoryInfo {
  supportApiMapSize: number;
  totalJsModules: number;
  isDestroyed: boolean;
  hasWebController: boolean;
}

/**
 * 模块工作参数接口
 */
export interface ModuleWorkParams {
  moduleName: string;
  timestamp: number;
}

/**
 * TipsJsBridge接口 - 用于解决循环引用的类型问题
 */
export interface ITipsJsBridge {
  registerModule(moduleName: string, module: Object): void;
  unregisterModule(moduleName: string): void;
  callJsMethod(moduleName: string, methodName: string, params?: Object): void;
  getAllModules(): Map<string, Object>;
  getMemoryInfo(): MemoryInfo;
  simulateMemoryLeak(): void;
  onCreate(): void;
  onStart(): void;
  onResume(): void;
  onPause(): void;
  onStop(): void;
  onDestroy(): void;
}