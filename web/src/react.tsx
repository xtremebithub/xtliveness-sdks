import * as React from 'react';
import { openCheck, type OpenOptions } from './index.js';

export interface XtlCheckProps extends Omit<OpenOptions, 'container' | 'onClose'> {
  className?: string;
  style?: React.CSSProperties;
}

/**
 * The face check inside your own layout. Give it a size (it fills its box). The check starts when the component mounts, once per checkUrl and
 * sdkToken (the token works once), and stops when it unmounts. Callbacks may change between renders without restarting the check.
 */
export function XtlCheck({ checkUrl, sdkToken, allowInsecureHttp, onComplete, onCancel, onError, className, style }: XtlCheckProps): React.ReactElement {
  const box = React.useRef<HTMLDivElement>(null);
  const callbacks = React.useRef({ onComplete, onCancel, onError });
  callbacks.current = { onComplete, onCancel, onError };

  React.useEffect(() => {
    const el = box.current;
    if (!el) return undefined;
    let handle: { close(): void } | null = null;
    try {
      handle = openCheck({
        checkUrl, sdkToken, allowInsecureHttp, container: el,
        onComplete: (r) => callbacks.current.onComplete?.(r),
        onCancel: () => callbacks.current.onCancel?.(),
        onError: (e) => callbacks.current.onError?.(e),
      });
    } catch {
      callbacks.current.onError?.({ code: 'invalid_check_address' });
    }
    return () => handle?.close();
  }, [checkUrl, sdkToken, allowInsecureHttp]);

  return React.createElement('div', { ref: box, className, style: { width: '100%', height: '100%', minHeight: 480, ...style } });
}
