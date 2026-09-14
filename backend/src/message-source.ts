import { fail } from './secure-validation';
export function sourceKind(value:unknown):string|undefined {
 if(value===undefined)return undefined;
 if(typeof value!=='string'||!['web','cli','api','subscription'].includes(value))fail(400,'invalid_source_kind');
 return value;
}
